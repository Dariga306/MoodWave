from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_optional, get_db
from app.models.music import ListeningAction, ListeningHistory, TrackCache
from app.models.user import User
from app.schemas.music import TrackResponse

router = APIRouter()

CHARTS_CACHE_TTL = 1800  # 30 min
PLAY_ACTIONS = [
    ListeningAction.played,
    ListeningAction.completed,
    ListeningAction.replayed,
]


async def _deezer_global_charts(limit: int) -> list[dict]:
    """Fetch real global top tracks from Deezer."""
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(
                "https://api.deezer.com/chart/0/tracks",
                params={"limit": limit},
            )
        if resp.status_code == 200:
            data = resp.json().get("data", [])
            return [
                {
                    "spotify_id": f"deezer_{t['id']}",
                    "title": t["title"],
                    "artist": t["artist"]["name"],
                    "album": t["album"]["title"],
                    "cover_url": t["album"].get("cover_xl") or t["album"].get("cover_medium"),
                    "preview_url": t.get("preview"),
                    "duration_ms": int(t.get("duration", 0)) * 1000,
                }
                for t in data
                if t.get("id")
            ]
    except Exception:
        pass
    return []


def _track_payload(track_id: str, cache: TrackCache | None) -> dict:
    if cache:
        return {
            "spotify_id": track_id,
            "title": cache.title,
            "artist": cache.artist,
            "album": cache.album,
            "genre": cache.genres[0] if cache.genres else None,
            "cover_url": cache.cover_url,
            "preview_url": cache.preview_url,
            "duration_ms": cache.duration_ms,
        }
    return {
        "spotify_id": track_id,
        "title": track_id,
        "artist": "",
        "album": None,
        "genre": None,
        "cover_url": None,
        "preview_url": None,
        "duration_ms": None,
    }


@router.get(
    "/city",
    response_model=list[TrackResponse],
    summary="Get city charts",
    description="Returns the most-played tracks for a city over the last 24 hours with cached metadata fallbacks.",
)
async def charts_by_city(
    city: str = Query(...),
    limit: int = Query(default=20, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    redis = request.app.state.redis
    cache_key = f"charts:v2:city:{city.lower()}:{limit}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    window_start = datetime.utcnow() - timedelta(hours=24)
    city_rows = (
        await db.execute(
            select(ListeningHistory.spotify_track_id, func.count(ListeningHistory.id).label("plays"))
            .join(User, User.id == ListeningHistory.user_id)
                .where(
                    func.lower(User.city) == city.lower(),
                    ListeningHistory.action.in_(PLAY_ACTIONS),
                    ListeningHistory.created_at >= window_start,
                )
            .group_by(ListeningHistory.spotify_track_id)
            .order_by(desc("plays"))
            .limit(limit)
        )
    ).all()

    # Step 2: city data last 7 days
    if not city_rows:
        window_7d = datetime.utcnow() - timedelta(days=7)
        city_rows = (
            await db.execute(
                select(ListeningHistory.spotify_track_id, func.count(ListeningHistory.id).label("plays"))
                .join(User, User.id == ListeningHistory.user_id)
                .where(
                    func.lower(User.city) == city.lower(),
                    ListeningHistory.action.in_(PLAY_ACTIONS),
                    ListeningHistory.created_at >= window_7d,
                )
                .group_by(ListeningHistory.spotify_track_id)
                .order_by(desc("plays"))
                .limit(limit)
            )
        ).all()

    # Step 3: global top from DB (all users, last 7 days)
    if not city_rows:
        window_7d = datetime.utcnow() - timedelta(days=7)
        city_rows = (
            await db.execute(
                select(ListeningHistory.spotify_track_id, func.count(ListeningHistory.id).label("plays"))
                .where(
                    ListeningHistory.created_at >= window_7d,
                    ListeningHistory.action.in_(PLAY_ACTIONS),
                )
                .group_by(ListeningHistory.spotify_track_id)
                .order_by(desc("plays"))
                .limit(limit)
            )
        ).all()

    if city_rows:
        result: list[dict] = []
        for track_id, _plays in city_rows:
            cache = await db.scalar(select(TrackCache).where(TrackCache.spotify_id == track_id))
            result.append(_track_payload(track_id, cache))
    else:
        # Step 4: Deezer global charts (real top 50, not keyword search)
        result = await _deezer_global_charts(limit)

    await redis.setex(cache_key, CHARTS_CACHE_TTL, json.dumps(result))
    return result
