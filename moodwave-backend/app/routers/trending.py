from __future__ import annotations

import asyncio
import json
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_current_user_optional, get_db
from app.models.music import ListeningHistory, TrackCache
from app.models.user import User
from app.services import deezer as deezer_service

router = APIRouter()

TRENDING_CACHE_TTL = 600  # 10 min
MIN_TRENDING_SAMPLE = 12


@router.get(
    "/tracks",
    summary="Hot trending tracks",
    description="Returns trending tracks with HOT/NEW/+N% badges based on Redis play counts.",
)
async def get_trending_tracks(
    request: Request,
    city: Optional[str] = Query(default=None),
    limit: int = Query(default=20, ge=1, le=50),
    current_user: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    redis = request.app.state.redis

    async def _deezer_fallback(reason: str, *, based_on: str) -> dict:
        try:
            cache_key = f"trending:deezer_fallback:{based_on}:{user_city or 'global'}:{limit}"
            cached = await redis.get(cache_key)
            if cached:
                payload = json.loads(cached)
                payload["reason"] = reason
                return payload
        except Exception:
            cache_key = None

        if based_on == "city_chart" and user_city:
            deezer_tracks = await deezer_service.get_city_chart_tracks(
                user_city.replace("_", " "),
                limit,
            )
        else:
            deezer_tracks = await deezer_service.get_chart_tracks(limit)

        tracks = [
            {
                "track_id": t["spotify_id"],
                "title": t["title"],
                "artist": t["artist"],
                "artist_id": str(t.get("artist_id") or ""),
                "album": t.get("album") or "",
                "cover_url": t.get("cover_url"),
                "preview_url": t.get("preview_url"),
                "duration_ms": t.get("duration_ms") or 0,
                "play_count": int(t.get("rank") or 0),
                "growth_percent": 0,
                "badge": "HOT",
            }
            for t in deezer_tracks
        ]

        payload = {"tracks": tracks, "based_on": based_on, "reason": reason}
        if cache_key and tracks:
            try:
                await redis.setex(cache_key, TRENDING_CACHE_TTL, json.dumps(payload))
            except Exception:
                pass
        return payload

    user_city = (
        city
        or (getattr(current_user, "city", None) if current_user else None)
        or ""
    ).lower().replace(" ", "_")

    try:
        city_key = f"trending:city:{user_city}"
        city_count = await redis.zcard(city_key) if user_city else 0
        trending_key = city_key if city_count >= MIN_TRENDING_SAMPLE else "trending:global"
        raw = await redis.zrevrange(trending_key, 0, limit - 1, withscores=True)
    except Exception:
        raw = []

    if not raw:
        fallback_based_on = "city_chart" if user_city else "global_chart"
        return await _deezer_fallback("not_enough_local_signal", based_on=fallback_based_on)

    track_ids = [item[0] for item in raw]
    scores = {item[0]: item[1] for item in raw}

    # Fetch track details from DB (один запрос)
    result = await db.execute(
        select(TrackCache).where(TrackCache.spotify_id.in_(track_ids))
    )
    tracks_db = {t.spotify_id: t for t in result.scalars().all()}

    yesterday_key = f"trending:snapshot:{(datetime.now(timezone.utc) - timedelta(days=1)).strftime('%Y%m%d')}"

    # FIX: Redis pipeline вместо N последовательных zscore вызовов
    # Было: for track_id in track_ids: await redis.zscore(yesterday_key, track_id)
    # → N отдельных round-trips к Redis
    # Стало: один pipeline с N командами → один round-trip
    try:
        async with redis.pipeline() as pipe:
            for tid in track_ids:
                pipe.zscore(yesterday_key, tid)
            yesterday_scores_raw = await pipe.execute()
    except Exception:
        yesterday_scores_raw = [None] * len(track_ids)

    yesterday_scores = {
        track_ids[i]: float(v) if v is not None else 0.0
        for i, v in enumerate(yesterday_scores_raw)
    }

    response_tracks = []
    for track_id in track_ids:
        track = tracks_db.get(track_id)
        if not track:
            continue

        current_score = scores.get(track_id, 0)
        yesterday_score = yesterday_scores.get(track_id, 0)

        growth = 0
        if yesterday_score > 0:
            growth = round(((current_score - yesterday_score) / yesterday_score) * 100)

        days_old = (datetime.utcnow() - (track.cached_at or datetime.utcnow())).days
        if days_old < 7:
            badge = "NEW"
        elif growth >= 200:
            badge = f"+{growth}%"
        else:
            badge = "HOT"

        response_tracks.append({
            "track_id": track.spotify_id,
            "title": track.title,
            "artist": track.artist,
            "album": track.album or "",
            "cover_url": track.cover_url,
            "preview_url": track.preview_url,
            "duration_ms": track.duration_ms or 0,
            "play_count": int(current_score),
            "growth_percent": growth,
            "badge": badge,
        })

    if len(response_tracks) < max(6, limit // 2):
        fallback_based_on = "city_chart" if user_city else "global_chart"
        return await _deezer_fallback("sparse_trending_cache", based_on=fallback_based_on)

    based_on = "city" if trending_key == city_key else "global"
    return {"tracks": response_tracks, "based_on": based_on}


@router.get(
    "/feed",
    summary="Home feed",
    description="Returns all home feed sections in a single parallel-loaded response.",
)
async def get_home_feed(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.routers.radio import STATION_CONFIG

    redis = request.app.state.redis

    async def _recently_played():
        try:
            rows = (
                await db.execute(
                    select(TrackCache)
                    .join(
                        ListeningHistory,
                        ListeningHistory.spotify_track_id == TrackCache.spotify_id,
                    )
                    .where(ListeningHistory.user_id == current_user.id)
                    .order_by(desc(ListeningHistory.created_at))
                    .limit(10)
                )
            ).scalars().all()
            seen = set()
            unique = []
            for t in rows:
                if t.spotify_id not in seen:
                    seen.add(t.spotify_id)
                    unique.append({
                        "spotify_id": t.spotify_id,
                        "title": t.title,
                        "artist": t.artist,
                        "cover_url": t.cover_url,
                        "preview_url": t.preview_url,
                        "duration_ms": t.duration_ms,
                    })
            return unique
        except Exception:
            return []

    async def _recommended_artists():
        try:
            from app.models.user import UserGenre
            genre_rows = (
                await db.execute(
                    select(UserGenre.genre)
                    .where(UserGenre.user_id == current_user.id)
                    .order_by(desc(UserGenre.weight))
                    .limit(5)
                )
            ).scalars().all()

            seed_queries = list(genre_rows)[:3] if genre_rows else ["pop", "indie", "electronic"]

            artists_found = []
            seen_names: set[str] = set()
            for query in seed_queries:
                try:
                    async with httpx.AsyncClient(timeout=5) as client:
                        resp = await client.get(
                            "https://api.deezer.com/search/artist",
                            params={"q": query, "limit": 8},
                        )
                        if resp.status_code == 200:
                            for a in resp.json().get("data", []):
                                name = a.get("name", "")
                                if name and name not in seen_names and len(artists_found) < 16:
                                    seen_names.add(name)
                                    pic = (
                                        a.get("picture_xl")
                                        or a.get("picture_big")
                                        or a.get("picture_medium")
                                    )
                                    if pic and "default" in pic:
                                        pic = None
                                    artists_found.append({
                                        "id": str(a.get("id", "")),
                                        "name": name,
                                        "photo_url": pic,
                                        "fans": a.get("nb_fan", 0),
                                    })
                except Exception:
                    pass
            return artists_found
        except Exception:
            return []

    async def _hot_tracks():
        try:
            result = await get_trending_tracks(
                request=request,
                city=None,
                limit=10,
                current_user=current_user,
                db=db,
            )
            return result.get("tracks", [])
        except Exception:
            return []

    recently_played, you_might_like, hot_right_now = await asyncio.gather(
        _recently_played(),
        _recommended_artists(),
        _hot_tracks(),
    )

    radio_stations = [
        {
            "id": sid,
            "name": cfg["name"],
            "emoji": cfg["emoji"],
            "subtitle": cfg["subtitle"],
            "accent_hex": cfg["accent_hex"],
        }
        for sid, cfg in STATION_CONFIG.items()
    ]

    return {
        "recently_played": recently_played,
        "you_might_like": you_might_like,
        "radio_stations": radio_stations,
        "hot_right_now": hot_right_now,
    }
