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

# ── Маппинг муд → жанры + поисковые запросы ──────────────────────────────────

MOOD_GENRES: dict[str, list[str]] = {
    "study":      ["classical", "jazz", "lo-fi", "ambient", "acoustic"],
    "workout":    ["electronic", "hip-hop", "rock", "metal", "pop"],
    "drive":      ["rock", "indie", "pop", "alternative", "country"],
    "sleep":      ["ambient", "classical", "acoustic", "new age", "lo-fi"],
    "party":      ["pop", "dance", "edm", "hip-hop", "r&b"],
    "chill":      ["r&b", "soul", "indie", "jazz", "lo-fi"],
    "morning":    ["pop", "indie", "acoustic", "folk", "soul"],
    "late_night": ["r&b", "lo-fi", "jazz", "ambient", "soul"],
    "sad":        ["indie", "folk", "alternative", "blues", "acoustic"],
    "romance":    ["r&b", "soul", "pop", "jazz", "acoustic"],
    "hype":       ["hip-hop", "electronic", "pop", "metal", "trap"],
    "meditate":   ["ambient", "classical", "new age", "acoustic", "lo-fi"],
    "rainy":      ["lo-fi", "acoustic", "folk", "indie", "ambient"],
    "beach":      ["reggae", "pop", "latin", "soul", "funk"],
}

MOOD_SEARCH_QUERIES: dict[str, list[str]] = {
    "study": [
        "lofi hip hop focus beats",
        "classical study music piano",
        "ambient instrumental concentration",
        "jazz cafe study music",
    ],
    "workout": [
        "hip hop workout motivation 2024",
        "edm gym energy pump",
        "rock workout running",
        "trap workout beats",
    ],
    "drive": [
        "indie road trip songs",
        "rock classic driving hits",
        "alternative feel good drive",
        "pop road trip playlist",
    ],
    "sleep": [
        "ambient sleep music relaxing",
        "classical piano sleep",
        "lofi chill sleep beats",
        "calm nature sounds meditation",
    ],
    "party": [
        "pop party hits 2024",
        "dance edm banger festival",
        "hip hop party club",
        "electronic dance music party",
    ],
    "chill": [
        "chill r&b vibes slow",
        "soul mellow chill music",
        "indie chill afternoon playlist",
        "lofi chill beats relax",
    ],
    "morning": [
        "morning acoustic feel good",
        "indie pop happy morning",
        "soul morning groove",
        "pop uplifting fresh start",
    ],
    "late_night": [
        "r&b late night vibes",
        "lofi jazz midnight",
        "neo soul night music",
        "ambient late night drive",
    ],
    "sad": [
        "sad indie emotional songs",
        "folk acoustic melancholy",
        "alternative sad songs heartbreak",
        "blues emotional slow",
    ],
    "romance": [
        "romantic r&b love songs",
        "soul love ballads classic",
        "acoustic romantic guitar",
        "jazz romantic evening",
    ],
    "hype": [
        "hip hop hype energy banger",
        "electronic hype festival drop",
        "trap hype motivation hard",
        "rap hype workout",
    ],
    "meditate": [
        "meditation ambient sounds",
        "tibetan bowls meditation music",
        "piano meditation calm",
        "nature ambient zen",
    ],
    "rainy": [
        "lofi rainy day music",
        "acoustic rainy afternoon",
        "indie folk cozy rain",
        "ambient rain piano",
    ],
    "beach": [
        "reggae summer beach vibes",
        "latin pop beach summer",
        "tropical summer hits",
        "funk soul beach party",
    ],
}

MOOD_CACHE_TTL = 3600  # 1 час
VALID_MOODS = set(MOOD_SEARCH_QUERIES.keys())


@router.get("/{mood_name}/tracks")
async def get_mood_tracks(
    mood_name: str,
    limit: int = 50,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    mood = mood_name.lower().strip()
    if mood not in VALID_MOODS:
        raise HTTPException(status_code=404, detail=f"Unknown mood: {mood_name}")

    redis = getattr(getattr(request, "app", None), "state", None)
    redis = getattr(redis, "redis", None) if redis else None

    cache_key = f"mood_tracks_v2:{mood}:{limit}"

    # Проверяем кэш
    if redis:
        try:
            cached = await redis.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

    tracks: list[dict] = []
    seen_ids: set[str] = set()

    genres = MOOD_GENRES.get(mood, [])

    # 1. Берём треки из кэша базы данных по жанрам
    for genre in genres[:4]:
        try:
            result = await db.execute(
                select(TrackCache)
                .where(TrackCache.genres.contains([genre]))
                .order_by(func.random())
                .limit(20)
            )
            rows = result.scalars().all()
            for row in rows:
                if row.spotify_id and row.spotify_id not in seen_ids and row.title:
                    tracks.append({
                        "spotify_id": row.spotify_id,
                        "title": row.title,
                        "artist": row.artist or "",
                        "cover_url": row.cover_url,
                        "preview_url": row.preview_url,
                        "duration_ms": row.duration_ms,
                    })
                    seen_ids.add(row.spotify_id)
            if len(tracks) >= limit:
                break
        except Exception as exc:
            logger.warning(
                "DB genre query failed for mood=%s genre=%s: %s", mood, genre, exc
            )

    # 2. Fallback: ищем через Deezer API
    if len(tracks) < limit:
        queries = MOOD_SEARCH_QUERIES.get(mood, [mood])
        needed = limit - len(tracks)
        per_query = max(15, needed // len(queries) + 5)

        for query in queries:
            try:
                results = await deezer_service.search_tracks(query, limit=per_query)
                for r in results:
                    rid = r.get("spotify_id") or r.get("deezer_id")
                    if rid and str(rid) not in seen_ids:
                        tracks.append(r)
                        seen_ids.add(str(rid))
                if len(tracks) >= limit:
                    break
            except Exception as exc:
                logger.warning(
                    "Deezer search failed for mood=%s query=%s: %s", mood, query, exc
                )

    tracks = tracks[:limit]

    # Сохраняем в кэш
    if redis and tracks:
        try:
            await redis.setex(cache_key, MOOD_CACHE_TTL, json.dumps(tracks))
        except Exception:
            pass

    return tracks


@router.post(
    "/{mood_name}/play",
    summary="Create mood playlist for playback",
    description="Returns tracks for the mood to populate the player queue.",
)
async def play_mood(
    mood_name: str,
    limit: int = 50,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    return await get_mood_tracks(
        mood_name, limit=limit, request=request, db=db, current_user=current_user
    )


@router.get("/", summary="List all available moods")
async def list_moods():
    """Возвращает список всех доступных настроений."""
    return [
        {"key": key, "genres": genres}
        for key, genres in MOOD_GENRES.items()
    ]