from __future__ import annotations

import json
import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_optional, get_db
from app.models.music import TrackCache
from app.models.user import User
from app.services import deezer as deezer_service

logger = logging.getLogger(__name__)
router = APIRouter()

MOOD_GENRES: dict[str, list[str]] = {
    "study": ["classical", "jazz", "lo-fi", "ambient"],
    "sport": ["electronic", "hip-hop", "rock", "pop"],
    "drive": ["rock", "indie", "pop", "alternative"],
    "sleep": ["ambient", "classical", "acoustic", "new age"],
    "party": ["pop", "dance", "edm", "hip-hop"],
    "chill": ["r&b", "soul", "indie", "jazz"],
}

MOOD_SEARCH_QUERIES: dict[str, list[str]] = {
    "study": ["lofi hip hop focus", "classical study music", "ambient instrumental study"],
    "sport": ["hip hop workout energy", "edm gym motivation", "rock workout"],
    "drive": ["indie road trip", "rock driving songs", "alternative feel good drive"],
    "sleep": ["ambient sleep music", "classical relaxing piano", "calm nature sounds"],
    "party": ["pop party hits 2024", "dance edm banger", "hip hop party"],
    "chill": ["chill r&b vibes", "soul mellow music", "indie chill playlist"],
}

MOOD_CACHE_TTL = 3600  # 1 hour
VALID_MOODS = set(MOOD_SEARCH_QUERIES.keys())


@router.get(
    "/{mood_name}/tracks",
    summary="Get tracks for a mood",
    description="Returns up to 20 tracks for the given mood. Cached in Redis for 1 hour.",
)
async def get_mood_tracks(
    mood_name: str,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    mood = mood_name.lower().strip()
    if mood not in VALID_MOODS:
        raise HTTPException(status_code=404, detail=f"Unknown mood: {mood_name}")

    redis = request.app.state.redis
    cache_key = f"mood_tracks:{mood}"

    try:
        cached = await redis.get(cache_key)
        if cached:
            return json.loads(cached)
    except Exception:
        pass

    tracks: list[dict] = []
    seen_ids: set[str] = set()

    # Try DB first: find tracks whose genres list contains a matching genre
    genres = MOOD_GENRES.get(mood, [])
    for genre in genres[:2]:
        try:
            rows = (
                await db.execute(
                    select(TrackCache)
                    .where(TrackCache.genres.cast(str).ilike(f"%{genre}%"))
                    .order_by(func.random())
                    .limit(20)
                )
            ).scalars().all()
            for row in rows:
                if row.spotify_id not in seen_ids and row.title:
                    tracks.append({
                        "spotify_id": row.spotify_id,
                        "title": row.title,
                        "artist": row.artist or "",
                        "cover_url": row.cover_url,
                        "preview_url": row.preview_url,
                        "duration_ms": row.duration_ms,
                    })
                    seen_ids.add(row.spotify_id)
            if len(tracks) >= 20:
                break
        except Exception as exc:
            logger.warning("DB genre query failed for mood=%s genre=%s: %s", mood, genre, exc)

    # Fallback: Deezer search for mood-specific queries
    if len(tracks) < 10:
        queries = MOOD_SEARCH_QUERIES.get(mood, [mood])
        for query in queries:
            try:
                results = await deezer_service.search_tracks(query, limit=20)
                for r in results:
                    rid = r.get("spotify_id") or r.get("deezer_id")
                    if rid and rid not in seen_ids:
                        tracks.append(r)
                        seen_ids.add(str(rid))
                if len(tracks) >= 20:
                    break
            except Exception as exc:
                logger.warning("Deezer search failed for mood=%s query=%r: %s", mood, query, exc)

    tracks = tracks[:20]

    try:
        await redis.setex(cache_key, MOOD_CACHE_TTL, json.dumps(tracks))
    except Exception:
        pass

    return tracks


@router.post(
    "/{mood_name}/play",
    summary="Create mood playlist for playback",
    description="Returns 20 tracks for the mood to populate the player queue.",
)
async def play_mood(
    mood_name: str,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    return await get_mood_tracks(
        mood_name, request=request, db=db, current_user=current_user
    )
