from __future__ import annotations

import asyncio
import json
from typing import Optional

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_optional, get_db
from app.models.user import User
from app.services import deezer as deezer_service

router = APIRouter()

CHARTS_CACHE_TTL = 1800   # 30 min
DISCOVER_CACHE_TTL = 600  # 10 min


def _fmt(t: dict, badge: str | None = None, play_count: int = 0) -> dict:
    return {
        "spotify_id": t.get("spotify_id") or t.get("deezer_id", ""),
        "deezer_id": t.get("deezer_id") or t.get("spotify_id", ""),
        "title": t.get("title", ""),
        "artist": t.get("artist", ""),
        "album": t.get("album"),
        "genre": None,
        "cover_url": t.get("cover_url"),
        "artist_picture": t.get("artist_picture"),
        "preview_url": t.get("preview_url"),
        "duration_ms": t.get("duration_ms"),
        "play_count": 0,
        "chart_position": int(t.get("rank") or 0),
        "badge": badge,
    }


def _dedupe_tracks(tracks: list[dict], limit: int) -> list[dict]:
    seen: set[str] = set()
    deduped: list[dict] = []
    for track in tracks:
        key = str(track.get("spotify_id") or track.get("deezer_id") or "").strip()
        if not key or key in seen:
            continue
        seen.add(key)
        deduped.append(track)
        if len(deduped) >= limit:
            break
    return deduped


@router.get(
    "/city",
    summary="Get city charts",
    description="Returns currently popular tracks for a city, sourced from Deezer charts.",
)
async def charts_by_city(
    city: str = Query(...),
    limit: int = Query(default=20, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    redis = request.app.state.redis
    cache_key = f"charts:v6:city:{city.lower()}:{limit}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    deezer_tracks = await deezer_service.get_city_chart_tracks(city, limit)
    if deezer_tracks:
        tracks = [_fmt(t) for t in deezer_tracks]
        city_lower = city.strip().lower()
        source = (
            "city"
            if city_lower in deezer_service.CITY_GENRE_HINTS
            or city_lower in deezer_service.CITY_SEARCH_HINTS
            else "global"
        )
    else:
        tracks = []
        source = "global"

    result = {"tracks": tracks, "source": source}
    await redis.setex(cache_key, CHARTS_CACHE_TTL, json.dumps(result))
    return result


@router.get(
    "/discover",
    summary="Discover feed — all sections in one call",
)
async def get_discover(
    request: Request,
    limit: int = Query(default=20, ge=5, le=50),
    city: Optional[str] = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    redis = request.app.state.redis
    effective_city = (
        city
        or (getattr(current_user, "city", None) if current_user else None)
        or ""
    ).strip()
    city_key = effective_city.lower()
    cache_key = f"charts:discover:v6:{city_key or 'global'}:{limit}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    city_hints = deezer_service.CITY_GENRE_HINTS.get(city_key, [])
    primary_genre = city_hints[0] if city_hints else "pop"
    secondary_genre = (
        city_hints[1]
        if len(city_hints) > 1
        else ("hip-hop" if primary_genre != "hip-hop" else "r&b")
    )
    tertiary_genre = (
        "electronic"
        if primary_genre != "electronic" and secondary_genre != "electronic"
        else "pop"
    )

    async def _global_top():
        tracks = await deezer_service.get_chart_tracks(limit)
        return [_fmt(t, badge=None, play_count=0) for t in tracks]

    async def _trending():
        if effective_city:
            tracks = await deezer_service.get_city_chart_tracks(effective_city, limit)
        else:
            tracks = await deezer_service.get_chart_tracks(limit)
        return [_fmt(t, badge="HOT", play_count=0) for t in tracks]

    async def _viral():
        if effective_city:
            tracks = await deezer_service.get_city_boost_tracks(effective_city, limit)
        else:
            tracks = await deezer_service.get_genre_chart_tracks(primary_genre, limit)
        if not tracks:
            tracks = await deezer_service.get_chart_tracks(limit)
        return [_fmt(t, badge="VIRAL", play_count=0) for t in tracks]

    async def _new_releases():
        tracks = await deezer_service.get_genre_chart_tracks(tertiary_genre, limit)
        if not tracks:
            tracks = await deezer_service.get_chart_tracks(limit)
        return [_fmt(t, badge="NEW", play_count=0) for t in tracks]

    async def _rising():
        tracks = await deezer_service.get_genre_chart_tracks(secondary_genre, limit)
        if not tracks:
            tracks = await deezer_service.get_chart_tracks(limit)
        return [_fmt(t, badge="↑", play_count=0) for t in tracks]

    global_top, trending, viral, new_releases, rising = await asyncio.gather(
        _global_top(), _trending(), _viral(), _new_releases(), _rising()
    )
    payload = {
        "city": effective_city,
        "source": "city" if city_key in deezer_service.CITY_GENRE_HINTS else "global",
        "global_top": _dedupe_tracks(global_top, limit),
        "trending": _dedupe_tracks(trending, limit),
        "viral": _dedupe_tracks(viral, limit),
        "new_releases": _dedupe_tracks(new_releases, limit),
        "rising": _dedupe_tracks(rising, limit),
    }
    await redis.setex(cache_key, DISCOVER_CACHE_TTL, json.dumps(payload))
    return payload
