from __future__ import annotations

import json
import random
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request

from app.dependencies import get_current_user
from app.models.user import User

router = APIRouter()

STATION_CONFIG: dict[str, dict] = {
    "late_night": {
        "name": "Late Night",
        "emoji": "🌙",
        "subtitle": "Calm · Atmospheric",
        "accent_hex": "#7C3AED",
        "deezer_genre": "Electro",
        "mood": "late_night",
        "keywords": "late night chill ambient",
    },
    "morning_boost": {
        "name": "Morning Boost",
        "emoji": "☀️",
        "subtitle": "Energetic · Upbeat",
        "accent_hex": "#D97706",
        "deezer_genre": "Pop",
        "mood": "happy",
        "keywords": "morning boost happy upbeat",
    },
    "deep_focus": {
        "name": "Deep Focus",
        "emoji": "🎧",
        "subtitle": "No lyrics · Flow",
        "accent_hex": "#0EA5E9",
        "deezer_genre": "Classical",
        "mood": "study",
        "keywords": "focus study instrumental",
    },
    "workout": {
        "name": "Workout",
        "emoji": "🏋️",
        "subtitle": "High Energy · Beast",
        "accent_hex": "#DC2626",
        "deezer_genre": "Hip-Hop",
        "mood": "workout",
        "keywords": "workout energy high bpm",
    },
    "road_trip": {
        "name": "Road Trip",
        "emoji": "🚗",
        "subtitle": "Feel the Wind",
        "accent_hex": "#059669",
        "deezer_genre": "Rock",
        "mood": "driving",
        "keywords": "road trip rock indie driving",
    },
    "sad_hours": {
        "name": "Sad Hours",
        "emoji": "🌧️",
        "subtitle": "Let It Out",
        "accent_hex": "#4338CA",
        "deezer_genre": "Indie",
        "mood": "sad",
        "keywords": "sad emotional slow",
    },
    "party_mode": {
        "name": "Party Mode",
        "emoji": "🎉",
        "subtitle": "Turn It Up",
        "accent_hex": "#DB2777",
        "deezer_genre": "Dance",
        "mood": "party",
        "keywords": "party dance edm",
    },
    "chill_vibes": {
        "name": "Chill Vibes",
        "emoji": "🌊",
        "subtitle": "Easy Sunday",
        "accent_hex": "#0891B2",
        "deezer_genre": "Jazz",
        "mood": "calm",
        "keywords": "chill vibes lofi jazz",
    },
}


async def _fetch_deezer_tracks(genre: str, keywords: str, limit: int = 20) -> list[dict]:
    """Fetch tracks from Deezer by genre search."""
    results = []
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(
                "https://api.deezer.com/search",
                params={"q": keywords, "limit": limit * 2, "order": "RATING_DESC"},
            )
            if resp.status_code == 200:
                data = resp.json().get("data", [])
                for t in data:
                    if not t.get("id"):
                        continue
                    results.append({
                        "id": f"deezer_{t['id']}",
                        "title": t.get("title", ""),
                        "artist": t.get("artist", {}).get("name", ""),
                        "artist_id": str(t.get("artist", {}).get("id", "")),
                        "album": t.get("album", {}).get("title", ""),
                        "cover_url": t.get("album", {}).get("cover_xl")
                            or t.get("album", {}).get("cover_medium"),
                        "preview_url": t.get("preview"),
                        "duration_ms": int(t.get("duration", 0)) * 1000,
                    })
    except Exception:
        pass
    random.shuffle(results)
    return results[:limit]


@router.get(
    "/stations",
    summary="List radio stations",
    description="Returns all 8 radio stations with metadata and current listener counts.",
)
async def list_radio_stations(request: Request):
    redis = request.app.state.redis
    stations = []
    for station_id, cfg in STATION_CONFIG.items():
        listener_count = 0
        try:
            raw = await redis.get(f"radio:listeners:{station_id}")
            listener_count = int(raw) if raw else 0
        except Exception:
            pass
        stations.append({
            "id": station_id,
            "name": cfg["name"],
            "emoji": cfg["emoji"],
            "subtitle": cfg["subtitle"],
            "accent_hex": cfg["accent_hex"],
            "listener_count": listener_count,
        })
    return {"stations": stations}


@router.get(
    "/{station_id}/tracks",
    summary="Get radio tracks",
    description="Returns a shuffled playlist for the given radio station, cached 30 min.",
)
async def get_radio_tracks(
    station_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    if station_id not in STATION_CONFIG:
        raise HTTPException(status_code=404, detail="Station not found")

    redis = request.app.state.redis
    cache_key = f"radio:{station_id}:{current_user.id}"
    cached = await redis.get(cache_key)
    if cached:
        tracks = json.loads(cached)
    else:
        cfg = STATION_CONFIG[station_id]
        tracks = await _fetch_deezer_tracks(cfg["deezer_genre"], cfg["keywords"])
        await redis.setex(cache_key, 1800, json.dumps(tracks))

    await redis.incr(f"radio:listeners:{station_id}")
    await redis.expire(f"radio:listeners:{station_id}", 3600)

    return {"station_id": station_id, "tracks": tracks}


@router.post(
    "/{station_id}/next",
    summary="Get next radio track",
    description="Returns the next track in the station queue, refreshing if exhausted.",
)
async def get_radio_next(
    station_id: str,
    body: dict,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    if station_id not in STATION_CONFIG:
        raise HTTPException(status_code=404, detail="Station not found")

    redis = request.app.state.redis
    cache_key = f"radio:{station_id}:{current_user.id}"
    cached = await redis.get(cache_key)
    current_id = body.get("current_track_id", "")

    if cached:
        tracks = json.loads(cached)
        idx = next((i for i, t in enumerate(tracks) if t["id"] == current_id), -1)
        next_idx = idx + 1
        if next_idx < len(tracks):
            return {"track": tracks[next_idx]}

    # Queue exhausted — fetch fresh batch
    await redis.delete(cache_key)
    result = await get_radio_tracks(station_id, request=request, current_user=current_user)
    tracks = result["tracks"]
    return {"track": tracks[0] if tracks else None}
