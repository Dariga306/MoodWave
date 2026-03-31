"""iTunes Search API — free, no auth required."""
import asyncio
import logging
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

BASE_URL = "https://itunes.apple.com/search"

GENRE_TERMS: dict[str, str] = {
    "pop": "pop",
    "rock": "rock",
    "hip-hop": "hip hop",
    "hip hop": "hip hop",
    "electronic": "electronic",
    "jazz": "jazz",
    "classical": "classical",
    "rnb": "r&b soul",
    "r&b": "r&b soul",
    "indie": "indie",
    "metal": "metal",
    "country": "country",
    "latin": "latin",
    "dance": "dance",
    "soul": "soul",
    "indie rock": "indie rock",
    "alt pop": "alternative pop",
    "k-pop": "k-pop",
    "ambient": "ambient",
    "lo-fi": "lo-fi",
    "punk": "punk rock",
    "reggae": "reggae",
    "blues": "blues",
    "folk": "folk",
    "funk": "funk",
}

MOOD_TERMS: dict[str, str] = {
    "happy": "happy upbeat",
    "sad": "sad emotional",
    "energetic": "energetic workout",
    "calm": "calm relaxing",
    "angry": "aggressive rock",
    "romantic": "romantic love",
    "melancholic": "melancholic",
    "sunny": "sunny summer",
    "rainy": "rainy day",
    "stormy": "dark intense",
    "cloudy": "indie chill",
    "foggy": "atmospheric ambient",
    "neutral": "popular hits",
    "study": "focus study",
    "late_night": "late night chill",
    "workout": "workout energy",
    "sleep": "sleep ambient",
    "driving": "driving road trip",
    "party": "party dance",
    "morning": "morning coffee",
}


def _parse_item(item: dict) -> dict:
    return {
        "spotify_id": str(item["trackId"]),
        "title": item.get("trackName", ""),
        "artist": item.get("artistName", ""),
        "album": item.get("collectionName"),
        "genre": item.get("primaryGenreName"),
        "cover_url": item.get("artworkUrl100", "").replace("100x100", "500x500"),
        "preview_url": item.get("previewUrl"),
        "duration_ms": item.get("trackTimeMillis"),
    }


async def search_tracks(query: str, limit: int = 20) -> list[dict]:
    params = {
        "term": query,
        "media": "music",
        "entity": "song",
        "limit": min(limit, 50),
        "country": "US",
    }
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(BASE_URL, params=params)
        resp.raise_for_status()
        data = resp.json()
    return [_parse_item(item) for item in data.get("results", []) if item.get("trackId")]


async def search_artists(query: str, limit: int = 10) -> list[dict]:
    params = {
        "term": query,
        "media": "music",
        "entity": "musicArtist",
        "limit": min(limit, 50),
    }
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(BASE_URL, params=params)
        resp.raise_for_status()
        data = resp.json()
    return [
        {
            "spotify_id": f"itunes_artist_{item.get('artistId', '')}",
            "name": item.get("artistName", ""),
            "image_url": None,
            "genres": [item.get("primaryGenreName", "")] if item.get("primaryGenreName") else [],
            "followers": 0,
        }
        for item in data.get("results", [])
        if item.get("artistId")
    ]


async def get_charts(genre: Optional[str] = None, limit: int = 20) -> list[dict]:
    term = GENRE_TERMS.get((genre or "").lower(), genre or "top hits")
    return await search_tracks(term, limit)


async def get_charts_by_city(city: str, limit: int = 20) -> list[dict]:
    # iTunes has no city-specific charts — return top hits with city as a genre hint
    return await search_tracks("top hits popular 2024", limit)


async def get_recommendations(
    mood_label: Optional[str] = None,
    seed_genres: Optional[list[str]] = None,
    target_energy: Optional[float] = None,
    target_valence: Optional[float] = None,
    limit: int = 20,
) -> list[dict]:
    if mood_label and mood_label.lower() in MOOD_TERMS:
        term = MOOD_TERMS[mood_label.lower()]
    elif seed_genres:
        term = GENRE_TERMS.get(seed_genres[0].lower(), seed_genres[0])
    elif target_energy is not None and target_energy > 0.7:
        term = "energetic upbeat"
    elif target_valence is not None and target_valence < 0.3:
        term = "sad emotional"
    elif target_energy is not None and target_energy < 0.4:
        term = "calm relaxing"
    else:
        term = "top popular hits"
    return await search_tracks(term, limit)
