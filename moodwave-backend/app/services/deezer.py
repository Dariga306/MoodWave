from __future__ import annotations

import httpx

BASE_URL = "https://api.deezer.com"


async def _get_json(path: str, params: dict | None = None) -> dict:
    async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client:
        response = await client.get(f"{BASE_URL}{path}", params=params)
        response.raise_for_status()
        return response.json()


def _map_track(item: dict, rank: int) -> dict:
    album = item.get("album") or {}
    artist = item.get("artist") or {}
    return {
        "spotify_id": str(item.get("id", "")),
        "deezer_id": str(item.get("id", "")),
        "artist_id": artist.get("id"),
        "title": item.get("title", ""),
        "artist": artist.get("name", ""),
        "album": album.get("title"),
        "cover_url": album.get("cover_xl")
        or album.get("cover_big")
        or album.get("cover_medium"),
        "preview_url": item.get("preview"),
        "duration_ms": int(item.get("duration", 0) or 0) * 1000,
        "rank": rank,
    }


async def get_artist(deezer_artist_id: int) -> dict | None:
    data = await _get_json(f"/artist/{deezer_artist_id}")
    if not data or data.get("error"):
        return None
    return {
        "id": data.get("id"),
        "name": data.get("name"),
        "picture_xl": data.get("picture_xl"),
        "nb_fan": data.get("nb_fan", 0),
        "nb_album": data.get("nb_album", 0),
    }


async def search_artist(query: str) -> dict | None:
    data = await _get_json("/search/artist", params={"q": query, "limit": 1})
    items = data.get("data") or []
    if not items:
        return None
    artist = items[0]
    return {
        "id": artist.get("id"),
        "name": artist.get("name"),
        "picture_xl": artist.get("picture_xl"),
        "nb_fan": artist.get("nb_fan", 0),
        "nb_album": artist.get("nb_album", 0),
    }


async def get_artist_top_tracks(deezer_artist_id: int, limit: int = 10) -> list[dict]:
    data = await _get_json(f"/artist/{deezer_artist_id}/top", params={"limit": limit})
    items = data.get("data") or []
    return [_map_track(item, index + 1) for index, item in enumerate(items[:limit])]


async def get_artist_albums(deezer_artist_id: int, limit: int = 8) -> list[dict]:
    data = await _get_json(f"/artist/{deezer_artist_id}/albums", params={"limit": limit})
    items = data.get("data") or []
    return [
        {
            "id": album.get("id"),
            "title": album.get("title"),
            "cover_xl": album.get("cover_xl")
            or album.get("cover_big")
            or album.get("cover_medium"),
            "release_date": album.get("release_date"),
            "nb_tracks": album.get("nb_tracks", 0),
        }
        for album in items[:limit]
    ]


async def get_album_detail(album_id: int) -> dict:
    data = await _get_json(f"/album/{album_id}")
    if not data or data.get("error"):
        return {}
    tracks_data = (data.get("tracks") or {}).get("data") or []
    artist = data.get("artist") or {}
    return {
        "id": data.get("id"),
        "title": data.get("title", ""),
        "cover_xl": data.get("cover_xl") or data.get("cover_big") or data.get("cover_medium"),
        "artist": artist.get("name", ""),
        "artist_id": artist.get("id"),
        "release_date": data.get("release_date", ""),
        "nb_tracks": data.get("nb_tracks", 0),
        "tracks": [_map_track(t, i + 1) for i, t in enumerate(tracks_data)],
    }


async def get_related_artists(deezer_artist_id: int, limit: int = 6) -> list[dict]:
    data = await _get_json(f"/artist/{deezer_artist_id}/related", params={"limit": limit})
    items = data.get("data") or []
    return [
        {
            "id": artist.get("id"),
            "name": artist.get("name"),
            "picture_medium": artist.get("picture_medium"),
            "picture_xl": artist.get("picture_xl"),
            "nb_fan": artist.get("nb_fan", 0),
        }
        for artist in items[:limit]
    ]
