"""
app/services/spotify.py — сервисный слой между роутером и Deezer API.

ДОБАВЛЕНО:
  - search_tracks()   — обёртка над deezer_service.search_tracks
  - get_track()       — детали трека по ID через Deezer /track/{id}
  - get_artist()      — детали артиста через deezer_service.get_artist
  - get_album()       — детали альбома через deezer_service.get_album
  - get_history()     — история прослушиваний из БД

Всё это вызывает music.py, но этих функций не было в файле.
"""
from __future__ import annotations

import json
import logging
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.music import ListeningHistory, TrackCache
from app.services import deezer as deezer_service

logger = logging.getLogger(__name__)

TRACK_CACHE_TTL = 300   # 5 минут
ARTIST_CACHE_TTL = 600  # 10 минут
ALBUM_CACHE_TTL = 300


# ──────────────────────────────────────────────────────────────────────────────
# Поиск треков
# ──────────────────────────────────────────────────────────────────────────────

async def search_tracks(
    q: str,
    limit: int = 20,
    redis=None,
) -> list[dict]:
    """
    Обёртка: music.py → spotify.search_tracks → deezer.search_tracks.
    Redis-кэш живёт в deezer.search_tracks, сюда прокидываем redis.
    """
    return await deezer_service.search_tracks(q, limit, redis=redis)


# ──────────────────────────────────────────────────────────────────────────────
# Детали трека
# ──────────────────────────────────────────────────────────────────────────────

async def get_track(
    track_id: str,
    redis=None,
) -> dict:
    """
    Детали одного трека по Deezer ID.
    Сначала ищем в Redis-кэше, потом в Deezer API.
    """
    cache_key = f"track:{track_id}"

    if redis:
        try:
            cached = await redis.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

    try:
        data = await deezer_service._get_json(f"/track/{track_id}")
    except Exception as exc:
        logger.warning("get_track failed id=%s: %s", track_id, exc)
        raise HTTPException(status_code=404, detail="Track not found")

    if not data or data.get("error"):
        raise HTTPException(status_code=404, detail="Track not found")

    # Используем _map_track для единообразия
    track = deezer_service._map_track(data, rank=1)

    if redis:
        try:
            await redis.setex(cache_key, TRACK_CACHE_TTL, json.dumps(track))
        except Exception:
            pass

    return track


# ──────────────────────────────────────────────────────────────────────────────
# Детали артиста
# ──────────────────────────────────────────────────────────────────────────────

async def get_artist(
    artist_id: str,
    redis=None,
) -> dict:
    """
    Детали артиста по Deezer artist ID.
    deezer.get_artist принимает int, конвертируем.
    """
    cache_key = f"artist:{artist_id}"

    if redis:
        try:
            cached = await redis.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

    try:
        artist_int_id = int(artist_id)
    except ValueError:
        raise HTTPException(status_code=422, detail="artist_id must be numeric")

    result = await deezer_service.get_artist(artist_int_id)

    if result is None:
        raise HTTPException(status_code=404, detail="Artist not found")

    # Дополнительно загружаем топ-треки артиста
    try:
        top_data = await deezer_service._get_json(
            f"/artist/{artist_int_id}/top",
            params={"limit": 10},
        )
        result["top_tracks"] = [
            deezer_service._map_track(t, i + 1)
            for i, t in enumerate(top_data.get("data") or [])
        ]
    except Exception:
        result["top_tracks"] = []

    if redis:
        try:
            await redis.setex(cache_key, ARTIST_CACHE_TTL, json.dumps(result))
        except Exception:
            pass

    return result


# ──────────────────────────────────────────────────────────────────────────────
# Детали альбома
# ──────────────────────────────────────────────────────────────────────────────

async def get_album(
    album_id: str,
    redis=None,
) -> dict:
    """
    Детали альбома по Deezer album ID:
      GET /album/{id}  → информация + треки
    """
    cache_key = f"album:{album_id}"

    if redis:
        try:
            cached = await redis.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

    try:
        data = await deezer_service._get_json(f"/album/{album_id}")
    except Exception as exc:
        logger.warning("get_album failed id=%s: %s", album_id, exc)
        raise HTTPException(status_code=404, detail="Album not found")

    if not data or data.get("error"):
        raise HTTPException(status_code=404, detail="Album not found")

    artist = data.get("artist") or {}
    album_cover = (
        data.get("cover_xl")
        or data.get("cover_big")
        or data.get("cover_medium")
    )

    tracks_data = (data.get("tracks") or {}).get("data") or []

    # Если треков нет в основном ответе — запрашиваем отдельно
    if not tracks_data:
        try:
            t_resp = await deezer_service._get_json(f"/album/{album_id}/tracks")
            tracks_data = t_resp.get("data") or []
        except Exception:
            pass

    tracks = []
    for i, t in enumerate(tracks_data):
        track = deezer_service._map_track(t, i + 1)
        if not track.get("cover_url"):
            track["cover_url"] = album_cover
        if not track.get("artist"):
            track["artist"] = artist.get("name", "")
        tracks.append(track)

    result = {
        "id": str(data.get("id", "")),
        "title": data.get("title", ""),
        "cover_url": album_cover,
        "artist": artist.get("name", ""),
        "artist_id": str(artist.get("id", "")),
        "release_date": data.get("release_date", ""),
        "nb_tracks": data.get("nb_tracks") or len(tracks),
        "tracks": tracks,
    }

    if redis:
        try:
            await redis.setex(cache_key, ALBUM_CACHE_TTL, json.dumps(result))
        except Exception:
            pass

    return result


# ──────────────────────────────────────────────────────────────────────────────
# История прослушиваний
# ──────────────────────────────────────────────────────────────────────────────

async def get_history(
    db: AsyncSession,
    limit: int = 50,
) -> list[dict]:
    """
    История прослушиваний из БД (таблица listening_history + tracks_cache).
    Примечание: без фильтра по пользователю — если нужна история конкретного
    пользователя, передавай current_user из роутера (сейчас history не требует auth).
    """
    try:
        rows = (
            await db.execute(
                select(ListeningHistory, TrackCache)
                .outerjoin(
                    TrackCache,
                    TrackCache.spotify_id == ListeningHistory.spotify_track_id,
                )
                .order_by(desc(ListeningHistory.created_at))
                .limit(limit)
            )
        ).all()

        result = []
        for history_row, cache_row in rows:
            entry = {
                "id": history_row.id,
                "spotify_track_id": history_row.spotify_track_id,
                "action": history_row.action.value if history_row.action else None,
                "created_at": history_row.created_at.isoformat(),
            }
            if cache_row:
                entry.update({
                    "title": cache_row.title,
                    "artist": cache_row.artist,
                    "album": cache_row.album,
                    "cover_url": cache_row.cover_url,
                    "preview_url": cache_row.preview_url,
                    "duration_ms": cache_row.duration_ms,
                })
            result.append(entry)

        return result

    except Exception as exc:
        logger.warning("get_history failed: %s", exc)
        return []


# ──────────────────────────────────────────────────────────────────────────────
# Поиск + кэширование треков в БД
# ──────────────────────────────────────────────────────────────────────────────

async def search_and_cache(
    query: str,
    limit: int,
    db: AsyncSession,
) -> list[dict]:
    """Поиск треков через Deezer."""
    try:
        return await deezer_service.search_tracks(query, limit)
    except Exception:
        return []


# ──────────────────────────────────────────────────────────────────────────────
# Чарты
# ──────────────────────────────────────────────────────────────────────────────

async def get_charts(
    genre: Optional[str] = None,
    limit: int = 20,
    redis=None,
) -> list[dict]:
    """
    Жанровый чарт → GET /chart/{genre_id}/tracks (реальный топ Deezer).
    Глобальный чарт → GET /chart/0/tracks.
    Redis TTL: 30 мин.
    """
    if genre:
        return await deezer_service.get_genre_chart_tracks(
            genre=genre,
            limit=limit,
            redis=redis,
        )
    return await deezer_service.get_chart_tracks(limit)


# ──────────────────────────────────────────────────────────────────────────────
# Чарты по городу
# ──────────────────────────────────────────────────────────────────────────────

async def get_charts_by_city(city: str, limit: int = 20) -> list[dict]:
    return await deezer_service.search_tracks(city, limit)


# ──────────────────────────────────────────────────────────────────────────────
# Рекомендации
# ──────────────────────────────────────────────────────────────────────────────

async def get_recommendations(
    seed_genres: list[str],
    mood_label: str | None = None,
    limit: int = 20,
    redis=None,
) -> list[dict]:
    return await deezer_service.get_recommendation_tracks(
        seed_genres=seed_genres,
        mood_label=mood_label,
        limit=limit,
        redis=redis,
    )