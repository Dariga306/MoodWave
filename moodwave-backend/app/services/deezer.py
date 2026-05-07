from __future__ import annotations

import re
from difflib import SequenceMatcher

import httpx

BASE_URL = "https://api.deezer.com"

GENRE_TERMS: dict[str, str] = {
    "pop": "pop",
    "rock": "rock",
    "hip-hop": "hip hop",
    "hip hop": "hip hop",
    "electronic": "electronic",
    "jazz": "jazz",
    "classical": "classical",
    "rnb": "r&b",
    "r&b": "r&b",
    "indie": "indie",
    "metal": "metal",
    "country": "country",
    "latin": "latin",
    "dance": "dance",
    "soul": "soul",
    "indie rock": "indie rock",
    "k-pop": "k-pop",
    "ambient": "ambient",
    "lo-fi": "lofi",
    "punk": "punk",
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
    "foggy": "ambient atmospheric",
    "neutral": "top hits",
    "study": "focus study",
    "late_night": "late night chill",
    "workout": "workout energy",
    "sleep": "sleep ambient",
    "driving": "driving road trip",
    "party": "party dance",
    "morning": "morning coffee",
}

try:
    from thefuzz import fuzz as _fuzz
except Exception:  # pragma: no cover - optional dependency
    _fuzz = None

# Simple in-process cache for artist data (avoids Deezer rate-limits on parallel loads)
_artist_cache: dict[int, dict] = {}


async def _get_json(path: str, params: dict | None = None) -> dict:
    async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
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
        "album_id": album.get("id"),
        "title": item.get("title", ""),
        "artist": artist.get("name", ""),
        "album": album.get("title"),
        "cover_url": album.get("cover_xl")
        or album.get("cover_big")
        or album.get("cover_medium"),
        "preview_url": item.get("preview") or None,
        "duration_ms": int(item.get("duration", 0) or 0) * 1000,
        "rank": rank,
    }


def _normalize_text(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def _score_similarity(left: str, right: str) -> int:
    if not left or not right:
        return 0
    if _fuzz is not None:
        return int(_fuzz.token_set_ratio(left, right))
    return int(SequenceMatcher(None, left, right).ratio() * 100)


def _score_artist_name(candidate_name: str, query: str) -> int:
    normalized_name = _normalize_text(candidate_name)
    normalized_query = _normalize_text(query)
    if not normalized_name or not normalized_query:
        return 0
    if normalized_name == normalized_query:
        return 200
    if normalized_name.startswith(normalized_query):
        return 170
    if normalized_query in normalized_name:
        return 140
    return _score_similarity(normalized_name, normalized_query)


async def get_artist(deezer_artist_id: int) -> dict | None:
    if deezer_artist_id in _artist_cache:
        return _artist_cache[deezer_artist_id]
    try:
        data = await _get_json(f"/artist/{deezer_artist_id}")
    except Exception:
        return None
    if not data or data.get("error"):
        return None
    result = {
        "id": data.get("id"),
        "name": data.get("name"),
        "picture_xl": data.get("picture_xl"),
        "picture_medium": data.get("picture_medium"),
        "nb_fan": data.get("nb_fan", 0),
        "nb_album": data.get("nb_album", 0),
    }
    _artist_cache[deezer_artist_id] = result
    return result


async def search_artist(query: str) -> dict | None:
    queries = [
        query,
        f'artist:"{query}"',
    ]
    seen_ids: set[int] = set()
    candidates: list[dict] = []

    for current_query in queries:
        try:
            data = await _get_json("/search/artist", params={"q": current_query, "limit": 10})
        except Exception:
            continue
        for artist in data.get("data") or []:
            artist_id = artist.get("id")
            if not artist_id or artist_id in seen_ids:
                continue
            seen_ids.add(artist_id)
            candidates.append(artist)

    if not candidates:
        return None

    best = max(
        candidates,
        key=lambda artist: (
            _score_artist_name(artist.get("name", ""), query),
            int(artist.get("nb_fan", 0) or 0),
        ),
    )
    return {
        "id": best.get("id"),
        "name": best.get("name"),
        "picture_xl": best.get("picture_xl"),
        "nb_fan": best.get("nb_fan", 0),
        "nb_album": best.get("nb_album", 0),
    }


async def get_artist_top_tracks(deezer_artist_id: int, limit: int = 10) -> list[dict]:
    data = await _get_json(f"/artist/{deezer_artist_id}/top", params={"limit": limit})
    items = data.get("data") or []
    return [_map_track(item, index + 1) for index, item in enumerate(items[:limit])]


async def get_artist_radio(deezer_artist_id: int, limit: int = 25) -> list[dict]:
    """Returns artist radio tracks (similar/related) from Deezer."""
    data = await _get_json(f"/artist/{deezer_artist_id}/radio", params={"limit": min(limit, 25)})
    items = data.get("data") or []
    return [_map_track(item, index + 1) for index, item in enumerate(items[:limit])]


async def get_artist_albums(deezer_artist_id: int, limit: int = 50) -> list[dict]:
    data = await _get_json(f"/artist/{deezer_artist_id}/albums", params={"limit": min(limit, 100)})
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
            "record_type": (album.get("record_type") or "album").lower(),
        }
        for album in items
    ]


async def get_album_detail(album_id: int) -> dict:
    data = await _get_json(f"/album/{album_id}")
    if not data or data.get("error"):
        return {}
    tracks_data = (data.get("tracks") or {}).get("data") or []
    artist = data.get("artist") or {}
    album_cover = (
        data.get("cover_xl") or data.get("cover_big") or data.get("cover_medium")
    )
    artist_name = artist.get("name", "")
    nb_tracks = data.get("nb_tracks", 0)

    # Fallback 1: if album main endpoint returned no/partial tracks,
    # hit the dedicated /tracks endpoint (different Deezer cache path)
    if not tracks_data:
        try:
            fallback = await _get_json(f"/album/{album_id}/tracks")
            tracks_data = fallback.get("data") or []
        except Exception:
            pass

    # Fallback 2: multiple search strategies to populate the track list
    if not tracks_data and artist_name:
        album_title = data.get("title", "")
        search_queries = []
        if album_title:
            search_queries.append(f"{artist_name} {album_title}")
            search_queries.append(album_title)
        search_queries.append(artist_name)

        for query in search_queries:
            try:
                searched = await search_tracks(query, limit=min(nb_tracks or 20, 25))
                if searched:
                    tracks = [
                        {**t, "cover_url": t.get("cover_url") or album_cover, "artist": t.get("artist") or artist_name}
                        for t in searched
                    ]
                    return {
                        "id": data.get("id"),
                        "title": album_title,
                        "cover_xl": album_cover,
                        "artist": artist_name,
                        "artist_id": artist.get("id"),
                        "release_date": data.get("release_date", ""),
                        "nb_tracks": nb_tracks or len(tracks),
                        "tracks": tracks,
                    }
            except Exception:
                pass

    tracks = []
    for i, t in enumerate(tracks_data):
        track = _map_track(t, i + 1)
        # Tracks from the album endpoint lack album/cover context — fill it in
        if not track.get("cover_url"):
            track["cover_url"] = album_cover
        if not track.get("artist"):
            track["artist"] = artist_name
        tracks.append(track)

    return {
        "id": data.get("id"),
        "title": data.get("title", ""),
        "cover_xl": album_cover,
        "artist": artist_name,
        "artist_id": artist.get("id"),
        "release_date": data.get("release_date", ""),
        "nb_tracks": nb_tracks or len(tracks),
        "tracks": tracks,
    }


async def get_album_tracks(deezer_album_id: int) -> list[dict]:
    data = await _get_json(f"/album/{deezer_album_id}/tracks")
    items = data.get("data") or []
    return [_map_track(item, index + 1) for index, item in enumerate(items)]


async def search_tracks(query: str, limit: int = 20) -> list[dict]:
    """Search tracks on Deezer. Handles multilingual queries natively."""
    try:
        data = await _get_json("/search", params={"q": query, "limit": min(limit, 50)})
        items = data.get("data") or []
        return [_map_track(item, i + 1) for i, item in enumerate(items[:limit])]
    except Exception:
        return []


async def get_chart_tracks(limit: int = 20) -> list[dict]:
    try:
        data = await _get_json("/chart/0/tracks", params={"limit": min(limit, 50)})
        items = data.get("data") or []
        return [_map_track(item, i + 1) for i, item in enumerate(items[:limit])]
    except Exception:
        return []


async def get_genre_chart_tracks(genre: str, limit: int = 20) -> list[dict]:
    term = GENRE_TERMS.get(genre.lower(), genre)
    tracks = await search_tracks(term, limit)
    if tracks:
        return tracks
    return await get_chart_tracks(limit)


async def get_recommendation_tracks(
    seed_genres: list[str],
    mood_label: str | None = None,
    limit: int = 20,
) -> list[dict]:
    term = None
    if mood_label:
        term = MOOD_TERMS.get(mood_label.lower(), mood_label)
    elif seed_genres:
        first_genre = seed_genres[0].lower()
        term = GENRE_TERMS.get(first_genre, seed_genres[0])

    tracks = await search_tracks(term or "top hits", limit)
    if tracks:
        return tracks
    return await get_chart_tracks(limit)


async def search_artists_list(query: str, limit: int = 10) -> list[dict]:
    """Search Deezer for multiple artist matches, scored and sorted by relevance."""
    queries = [query, f'artist:"{query}"']
    seen_ids: set[int] = set()
    candidates: list[dict] = []

    for current_query in queries:
        try:
            data = await _get_json(
                "/search/artist",
                params={"q": current_query, "limit": min(limit * 5, 50)},
            )
        except Exception:
            continue
        for artist in data.get("data") or []:
            artist_id = artist.get("id")
            if not artist_id or artist_id in seen_ids:
                continue
            seen_ids.add(artist_id)
            candidates.append(artist)

    candidates.sort(
        key=lambda a: (
            _score_artist_name(a.get("name", ""), query),
            int(a.get("nb_fan", 0) or 0),
        ),
        reverse=True,
    )

    return [
        {
            "id": a.get("id"),
            "name": a.get("name"),
            "picture_xl": a.get("picture_xl"),
            "picture_medium": a.get("picture_medium"),
            "nb_fan": a.get("nb_fan", 0),
            "nb_album": a.get("nb_album", 0),
        }
        for a in candidates[:limit]
    ]


async def search_albums(query: str, limit: int = 10) -> list[dict]:
    """Search Deezer for albums matching the query."""
    try:
        data = await _get_json("/search/album", params={"q": query, "limit": min(limit, 50)})
        items = [
            {
                "id": a.get("id"),
                "title": a.get("title"),
                "cover_xl": a.get("cover_xl") or a.get("cover_big") or a.get("cover_medium"),
                "artist": (a.get("artist") or {}).get("name", ""),
                "artist_id": (a.get("artist") or {}).get("id"),
                "release_date": a.get("release_date", ""),
                "nb_tracks": a.get("nb_tracks", 0),
            }
            for a in (data.get("data") or [])
        ]
        normalized_query = query.strip().lower()

        def _score(album: dict) -> tuple[int, int, int, str]:
            title = (album.get("title") or "").strip().lower()
            artist = (album.get("artist") or "").strip().lower()
            title_exact = int(title == normalized_query)
            title_prefix = int(title.startswith(normalized_query))
            title_contains = int(normalized_query in title) if normalized_query else 0
            artist_contains = int(normalized_query in artist) if normalized_query else 0
            track_count = int(album.get("nb_tracks") or 0)
            return (
                title_exact * 100 + title_prefix * 40 + title_contains * 20 + artist_contains * 10,
                track_count,
                -int(album.get("id") or 0),
                title,
            )

        items.sort(key=_score, reverse=True)
        return items[:limit]
    except Exception:
        return []


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
