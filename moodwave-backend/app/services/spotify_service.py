"""Spotify API — search and recommendations using Client Credentials flow.

Client Credentials gives metadata (title, artist, cover, spotify_uri) without
requiring user login. Audio playback is handled separately by the SDK / Web
Playback SDK.
"""
import logging
import time
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_TOKEN_URL = "https://accounts.spotify.com/api/token"
_SEARCH_URL = "https://api.spotify.com/v1/search"
_RECS_URL = "https://api.spotify.com/v1/recommendations"

# Module-level token cache
_client_token: Optional[str] = None
_client_token_expires: float = 0.0

_MOOD_QUERIES: dict[str, str] = {
    "study": "focus study instrumental",
    "workout": "workout energy pump",
    "sleep": "sleep ambient calm",
    "party": "party dance hits",
    "sad": "sad emotional",
    "driving": "driving road trip",
    "morning": "morning coffee chill",
    "late_night": "late night chill",
    "happy": "happy upbeat",
    "energetic": "energetic upbeat",
    "calm": "calm relaxing",
    "romantic": "romantic love",
}


async def get_client_token() -> str:
    global _client_token, _client_token_expires
    if _client_token and time.time() < _client_token_expires - 30:
        return _client_token

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            _TOKEN_URL,
            data={"grant_type": "client_credentials"},
            auth=(settings.SPOTIFY_CLIENT_ID, settings.SPOTIFY_CLIENT_SECRET),
        )
        resp.raise_for_status()
        data = resp.json()

    _client_token = data["access_token"]
    _client_token_expires = time.time() + data.get("expires_in", 3600)
    logger.debug("Spotify client token refreshed, expires in %s s", data.get("expires_in"))
    return _client_token


def _parse_track(track: dict) -> dict:
    images = track.get("album", {}).get("images", [])
    return {
        "spotify_id": track["id"],
        "title": track["name"],
        "artist": ", ".join(a["name"] for a in track.get("artists", [])),
        "album": track.get("album", {}).get("name"),
        "cover_url": images[0]["url"] if images else None,
        "preview_url": None,  # Spotify removed preview_url in late 2024
        "duration_ms": track.get("duration_ms"),
        "spotify_uri": track["uri"],  # e.g. "spotify:track:4uLU6hMCjMI75M1A2tKUQC"
    }


async def search_tracks(query: str, limit: int = 20) -> list[dict]:
    token = await get_client_token()
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            _SEARCH_URL,
            params={"q": query, "type": "track", "market": "KZ", "limit": min(limit, 50)},
            headers={"Authorization": f"Bearer {token}"},
        )
        resp.raise_for_status()
        data = resp.json()
    return [_parse_track(t) for t in data.get("tracks", {}).get("items", []) if t]


async def search_artists(query: str, limit: int = 10) -> list[dict]:
    token = await get_client_token()
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            _SEARCH_URL,
            params={"q": query, "type": "artist", "market": "KZ", "limit": min(limit, 50)},
            headers={"Authorization": f"Bearer {token}"},
        )
        resp.raise_for_status()
        data = resp.json()
    artists = data.get("artists", {}).get("items", [])
    return [
        {
            "spotify_id": a["id"],
            "name": a["name"],
            "image_url": a["images"][0]["url"] if a.get("images") else None,
            "genres": a.get("genres", []),
            "followers": a.get("followers", {}).get("total", 0),
        }
        for a in artists
        if a
    ]


async def get_charts(genre: Optional[str] = None, limit: int = 20) -> list[dict]:
    query = genre if genre else "top hits 2024"
    return await search_tracks(query, limit)


async def get_charts_by_city(city: str, limit: int = 20) -> list[dict]:
    return await search_tracks("top hits popular 2024", limit)


async def get_recommendations(
    seed_genres: Optional[list[str]] = None,
    seed_tracks: Optional[list[str]] = None,
    mood_label: Optional[str] = None,
    target_energy: Optional[float] = None,
    target_valence: Optional[float] = None,
    limit: int = 20,
) -> list[dict]:
    # If we have seed track Spotify IDs, use the recommendations endpoint
    if seed_tracks:
        # Filter to valid Spotify IDs (not iTunes IDs)
        valid_seeds = [t for t in seed_tracks if not t.startswith("itunes_")][:5]
        if valid_seeds:
            token = await get_client_token()
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(
                    _RECS_URL,
                    params={
                        "seed_tracks": ",".join(valid_seeds),
                        "limit": limit,
                        "market": "KZ",
                    },
                    headers={"Authorization": f"Bearer {token}"},
                )
            if resp.status_code == 200:
                data = resp.json()
                tracks = [_parse_track(t) for t in data.get("tracks", []) if t]
                if tracks:
                    return tracks

    # Fall back to search based on mood or energy/valence
    query = _MOOD_QUERIES.get(mood_label or "", "")
    if not query:
        if target_energy is not None and target_energy > 0.7:
            query = "energetic upbeat"
        elif target_valence is not None and target_valence < 0.3:
            query = "sad emotional"
        elif target_energy is not None and target_energy < 0.4:
            query = "calm relaxing"
        elif seed_genres:
            query = seed_genres[0]
        else:
            query = "top popular hits"

    return await search_tracks(query, limit)
