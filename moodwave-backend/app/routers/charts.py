from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_optional, get_db
from app.models.music import ListeningHistory, TrackCache
from app.models.user import User
from app.schemas.music import TrackResponse
from app.services import itunes

router = APIRouter()

CHARTS_CACHE_TTL = 3600


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
    cache_key = f"charts:city:{city.lower()}:{limit}"
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
                ListeningHistory.created_at >= window_start,
            )
            .group_by(ListeningHistory.spotify_track_id)
            .order_by(desc("plays"))
            .limit(limit)
        )
    ).all()

    rows = city_rows
    if not rows:
        rows = (
            await db.execute(
                select(ListeningHistory.spotify_track_id, func.count(ListeningHistory.id).label("plays"))
                .where(ListeningHistory.created_at >= window_start)
                .group_by(ListeningHistory.spotify_track_id)
                .order_by(desc("plays"))
                .limit(limit)
            )
        ).all()

    if rows:
        result: list[dict] = []
        for track_id, _plays in rows:
            cache = await db.scalar(select(TrackCache).where(TrackCache.spotify_id == track_id))
            result.append(_track_payload(track_id, cache))
    else:
        # iTunes fallback when no listening history exists
        try:
            result = await itunes.search_tracks(f"top hits {city}", limit)
            if not result:
                result = await itunes.get_charts(limit=limit)
        except Exception:
            result = []

    await redis.setex(cache_key, CHARTS_CACHE_TTL, json.dumps(result))
    return result
