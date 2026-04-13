from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.music import TrackCache
from app.services import deezer as deezer_service


TRACK_CACHE_FIELDS = {
    "spotify_id",
    "title",
    "artist",
    "album",
    "cover_url",
    "preview_url",
    "duration_ms",
}


async def search_and_cache(query: str, limit: int, db: AsyncSession) -> list[dict]:
    tracks = await deezer_service.search_tracks(query, limit)

    for track_data in tracks:
        cache_payload = {
            key: value for key, value in dict(track_data).items() if key in TRACK_CACHE_FIELDS
        }
        genre = track_data.get("genre")
        existing = await db.scalar(
            select(TrackCache).where(TrackCache.spotify_id == track_data["spotify_id"])
        )
        if not existing:
            try:
                tc = TrackCache(
                    **cache_payload,
                    genres=[genre] if genre else [],
                    audio_features={},
                )
                db.add(tc)
            except Exception:
                pass
    if tracks:
        try:
            await db.commit()
        except Exception:
            await db.rollback()
    return tracks


async def search_artists(query: str, limit: int = 10) -> list[dict]:
    artist = await deezer_service.search_artist(query)
    return [artist] if artist else []


async def get_charts(genre: Optional[str] = None, limit: int = 20) -> list[dict]:
    if genre:
        return await deezer_service.get_genre_chart_tracks(genre, limit)
    return await deezer_service.get_chart_tracks(limit)


async def get_charts_by_city(city: str, limit: int = 20) -> list[dict]:
    return await deezer_service.get_chart_tracks(limit)


async def get_recommendations_from_spotify(
    seed_genres: list[str],
    seed_tracks: list[str],
    target_energy: Optional[float] = None,
    target_valence: Optional[float] = None,
    mood_label: Optional[str] = None,
    limit: int = 20,
) -> list[dict]:
    return await deezer_service.get_recommendation_tracks(
        seed_genres=seed_genres,
        mood_label=mood_label,
        limit=limit,
    )
