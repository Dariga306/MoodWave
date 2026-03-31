"""Music service — iTunes Search API (primary) with Spotify metadata where available."""
import logging
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.music import TrackCache
from app.services import itunes

logger = logging.getLogger(__name__)


async def search_and_cache(query: str, limit: int, db: AsyncSession) -> list[dict]:
    tracks = await itunes.search_tracks(query, limit)
    for track_data in tracks:
        cache_payload = dict(track_data)
        genre = cache_payload.pop("genre", None)
        existing = await db.scalar(
            select(TrackCache).where(TrackCache.spotify_id == track_data["spotify_id"])
        )
        if not existing:
            tc = TrackCache(
                **cache_payload,
                genres=[genre] if genre else [],
                audio_features={},
            )
            db.add(tc)
    if tracks:
        await db.commit()
    return tracks


async def search_artists(query: str, limit: int = 10) -> list[dict]:
    return await itunes.search_artists(query, limit)


async def get_charts(genre: Optional[str] = None, limit: int = 20) -> list[dict]:
    return await itunes.get_charts(genre, limit)


async def get_charts_by_city(city: str, limit: int = 20) -> list[dict]:
    return await itunes.get_charts_by_city(city, limit)


async def get_recommendations_from_spotify(
    seed_genres: list[str],
    seed_tracks: list[str],
    target_energy: Optional[float] = None,
    target_valence: Optional[float] = None,
    mood_label: Optional[str] = None,
    limit: int = 20,
) -> list[dict]:
    return await itunes.get_recommendations(
        mood_label=mood_label,
        seed_genres=seed_genres,
        target_energy=target_energy,
        target_valence=target_valence,
        limit=limit,
    )
