from __future__ import annotations

import asyncio
import json
import logging
import re
from collections import OrderedDict
from difflib import SequenceMatcher

import httpx

logger = logging.getLogger(__name__)

BASE_URL = "https://api.deezer.com"

# ──────────────────────────────────────────────────────────────────────────────
# Singleton HTTP client
# ──────────────────────────────────────────────────────────────────────────────

_DEEZER_CLIENT: httpx.AsyncClient | None = None


def get_client() -> httpx.AsyncClient:
    """Возвращает singleton AsyncClient."""
    global _DEEZER_CLIENT

    if _DEEZER_CLIENT is None or _DEEZER_CLIENT.is_closed:
        _DEEZER_CLIENT = httpx.AsyncClient(
            base_url=BASE_URL,
            timeout=15,
            follow_redirects=True,
            limits=httpx.Limits(
                max_connections=20,
                max_keepalive_connections=10,
            ),
        )

    return _DEEZER_CLIENT


async def close_client() -> None:
    """Закрыть HTTP client при shutdown."""
    global _DEEZER_CLIENT

    if _DEEZER_CLIENT and not _DEEZER_CLIENT.is_closed:
        await _DEEZER_CLIENT.aclose()

    _DEEZER_CLIENT = None


# ──────────────────────────────────────────────────────────────────────────────
# Genre IDs
# ──────────────────────────────────────────────────────────────────────────────

GENRE_IDS: dict[str, int] = {
    "pop": 132,
    "rock": 152,
    "hip-hop": 116,
    "hip hop": 116,
    "rap": 116,
    "electronic": 106,
    "dance": 106,
    "edm": 106,
    "jazz": 129,
    "classical": 98,
    "r&b": 165,
    "rnb": 165,
    "soul": 169,
    "funk": 169,
    "reggae": 144,
    "country": 84,
    "latin": 197,
    "alternative": 85,
    "indie": 85,
    "metal": 464,
    "blues": 122,
    "folk": 169,
    "ambient": 106,
    "lo-fi": 106,
    "punk": 152,
    "k-pop": 132,
    "kpop": 132,
    "indie rock": 152,
    "trap": 116,
    "drill": 116,
    "afrobeats": 197,
}

GENRE_CACHE_TTL = 1800
TRACK_CACHE_TTL = 300

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────


async def _get_json(path: str, params: dict | None = None) -> dict:
    """
    GET request with retry.
    """

    last_error = None

    for attempt in range(3):
        try:
            response = await get_client().get(path, params=params)
            response.raise_for_status()
            return response.json()

        except Exception as exc:
            last_error = exc

            if attempt < 2:
                await asyncio.sleep(0.5 * (attempt + 1))

    logger.warning("Deezer request failed: %s %s", path, last_error)
    return {}


def _map_track(item: dict, rank: int) -> dict:
    album = item.get("album") or {}
    artist = item.get("artist") or {}
    contributors = item.get("contributors") or []

    artists: list[dict] = []
    seen_ids: set = set()

    for c in contributors:
        aid = c.get("id")
        name = c.get("name", "")

        key = aid or name

        if not key or key in seen_ids:
            continue

        seen_ids.add(key)

        artists.append({
            "id": aid,
            "name": name,
        })

    if not artists and artist.get("name"):
        artists.append({
            "id": artist.get("id"),
            "name": artist.get("name", ""),
        })

    return {
        "spotify_id": str(item.get("id", "")),
        "deezer_id": str(item.get("id", "")),
        "artist_id": artist.get("id"),
        "artist_ids": [e["id"] for e in artists if e.get("id")],
        "album_id": album.get("id"),
        "title": item.get("title", ""),
        "artist": ", ".join(
            e["name"].strip()
            for e in artists
            if e.get("name")
        ) or artist.get("name", ""),
        "artists": artists,
        "album": album.get("title"),
        "cover_url": (
            album.get("cover_xl")
            or album.get("cover_big")
            or album.get("cover_medium")
        ),
        "artist_picture": (
            artist.get("picture_xl")
            or artist.get("picture_big")
            or artist.get("picture_medium")
        ),
        "preview_url": item.get("preview") or None,
        "duration_ms": int(item.get("duration", 0) or 0) * 1000,
        "rank": rank,
        "score": int(item.get("rank", 0) or 0),
    }


def _map_album(item: dict) -> dict:
    artist = item.get("artist") or {}
    return {
        "id": str(item.get("id", "")),
        "title": item.get("title", ""),
        "artist": artist.get("name", ""),
        "artist_id": str(artist.get("id", "")),
        "cover_url": (
            item.get("cover_xl")
            or item.get("cover_big")
            or item.get("cover_medium")
        ),
        "nb_tracks": item.get("nb_tracks", 0),
        "release_date": item.get("release_date"),
    }


def _normalize_text(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


try:
    from thefuzz import fuzz as _fuzz
except Exception:
    _fuzz = None


def _score_similarity(left: str, right: str) -> int:
    if not left or not right:
        return 0

    if _fuzz is not None:
        return int(_fuzz.token_set_ratio(left, right))

    return int(SequenceMatcher(None, left, right).ratio() * 100)


def _score_track(track: dict, query: str) -> int:
    """
    Local reranking поверх Deezer search.
    """

    q = _normalize_text(query)

    title = _normalize_text(track.get("title", ""))
    artist = _normalize_text(track.get("artist", ""))

    score = 0

    if artist == q:
        score += 300

    if artist.startswith(q):
        score += 180

    if q in artist:
        score += 120

    if title == q:
        score += 100

    if title.startswith(q):
        score += 70

    if q in title:
        score += 40

    return score


def _score_artist_name(candidate_name: str, query: str) -> int:
    n = _normalize_text(candidate_name)
    q = _normalize_text(query)

    if not n or not q:
        return 0

    if n == q:
        return 200

    if n.startswith(q):
        return 170

    if q in n:
        return 140

    return _score_similarity(n, q)


# ──────────────────────────────────────────────────────────────────────────────
# FIX: Artist cache — ограниченный LRU dict, не растёт бесконечно
# Было: _artist_cache: dict[int, dict] = {}   (unbounded — утечка памяти)
# Стало: OrderedDict с eviction при превышении лимита
# ──────────────────────────────────────────────────────────────────────────────

_artist_cache: OrderedDict[int, dict] = OrderedDict()
ARTIST_CACHE_MAX = 500


def _put_artist_cache(artist_id: int, data: dict) -> None:
    if artist_id in _artist_cache:
        _artist_cache.move_to_end(artist_id)
    _artist_cache[artist_id] = data
    if len(_artist_cache) > ARTIST_CACHE_MAX:
        _artist_cache.popitem(last=False)  # evict oldest


# ──────────────────────────────────────────────────────────────────────────────
# Search tracks
# ──────────────────────────────────────────────────────────────────────────────


async def search_tracks(
    query: str,
    limit: int = 100,
    redis=None,
) -> list[dict]:
    """
    Deezer track search + local reranking + Redis cache.
    """

    q = query.strip()

    if not q:
        return []

    # FIX: ключ включает limit — разные limit дают разные кэши
    cache_key = f"search:tracks:{q.lower()}:{limit}"

    # Redis HIT
    if redis:
        try:
            cached = await redis.get(cache_key)

            if cached:
                logger.debug("search tracks cache HIT: %s", cache_key)
                return json.loads(cached)

        except Exception:
            pass

    try:
        data = await _get_json(
            "/search",
            params={
                "q": q,
                "limit": min(limit, 100),
            },
        )

        tracks = [
            _map_track(item, i + 1)
            for i, item in enumerate(data.get("data") or [])
        ]

        # local reranking
        tracks.sort(
            key=lambda t: _score_track(t, q),
            reverse=True,
        )

        tracks = tracks[:limit]

        # cache
        if redis and tracks:
            try:
                await redis.setex(
                    cache_key,
                    TRACK_CACHE_TTL,
                    json.dumps(tracks),
                )
            except Exception:
                pass

        return tracks

    except Exception as exc:
        logger.warning("search_tracks failed: %s", exc)
        return []


# ──────────────────────────────────────────────────────────────────────────────
# Search albums  (NEW — нужен для шага 2: /search возвращает albums)
# ──────────────────────────────────────────────────────────────────────────────

ALBUM_CACHE_TTL = 300


async def search_albums(
    query: str,
    limit: int = 10,
    redis=None,
) -> list[dict]:
    """
    Deezer album search + Redis cache.
    """

    q = query.strip()
    if not q:
        return []

    cache_key = f"search:albums:{q.lower()}:{limit}"

    if redis:
        try:
            cached = await redis.get(cache_key)
            if cached:
                logger.debug("search albums cache HIT: %s", cache_key)
                return json.loads(cached)
        except Exception:
            pass

    try:
        data = await _get_json(
            "/search/album",
            params={"q": q, "limit": min(limit * 2, 50)},
        )

        albums = [
            _map_album(item)
            for item in (data.get("data") or [])
        ][:limit]

        if redis and albums:
            try:
                await redis.setex(cache_key, ALBUM_CACHE_TTL, json.dumps(albums))
            except Exception:
                pass

        return albums

    except Exception as exc:
        logger.warning("search_albums failed: %s", exc)
        return []


# ──────────────────────────────────────────────────────────────────────────────
# Genre charts
# ──────────────────────────────────────────────────────────────────────────────


async def _fetch_genre_chart(
    genre_id: int,
    limit: int,
) -> list[dict]:
    try:
        data = await _get_json(
            f"/chart/{genre_id}/tracks",
            params={"limit": min(limit, 100)},
        )

        items = data.get("data") or []

        return [
            _map_track(item, i + 1)
            for i, item in enumerate(items[:limit])
        ]

    except Exception as exc:
        logger.warning(
            "genre chart failed: genre_id=%s error=%s",
            genre_id,
            exc,
        )
        return []


async def _kpop_tracks(limit: int) -> list[dict]:
    kpop_queries = [
        "BTS",
        "BLACKPINK",
        "TWICE",
        "aespa",
        "NewJeans",
        "Stray Kids",
    ]

    seen: set[str] = set()
    tracks: list[dict] = []

    results = await asyncio.gather(
        *[
            search_tracks(q, limit=5)
            for q in kpop_queries
        ],
        return_exceptions=True,
    )

    for batch in results:
        if isinstance(batch, Exception):
            continue

        for track in batch:
            tid = track.get("deezer_id", "")

            if tid and tid not in seen:
                seen.add(tid)
                tracks.append(track)

        if len(tracks) >= limit:
            break

    for i, track in enumerate(tracks[:limit]):
        track["rank"] = i + 1

    return tracks[:limit]


async def _cache_genre(
    redis,
    key: str,
    tracks: list[dict],
) -> None:
    if not redis or not tracks:
        return

    try:
        await redis.setex(
            key,
            GENRE_CACHE_TTL,
            json.dumps(tracks),
        )

    except Exception:
        pass


async def get_genre_chart_tracks(
    genre: str,
    limit: int = 100,
    redis=None,
) -> list[dict]:
    """
    Real genre charts через Deezer Chart API.
    """

    slug = genre.strip().lower()

    cache_key = f"genre:chart:{slug}:{limit}"

    # cache HIT
    if redis:
        try:
            cached = await redis.get(cache_key)

            if cached:
                logger.debug("genre chart cache HIT: %s", cache_key)
                return json.loads(cached)

        except Exception:
            pass

    # K-Pop special case
    if slug in ("k-pop", "kpop"):
        tracks = await _kpop_tracks(limit)

        if tracks:
            await _cache_genre(redis, cache_key, tracks)

        return tracks

    # Real Deezer genre chart
    genre_id = GENRE_IDS.get(slug)

    if genre_id:
        tracks = await _fetch_genre_chart(
            genre_id,
            limit,
        )

        if tracks:
            logger.info(
                "genre chart OK genre=%s id=%s n=%s",
                slug,
                genre_id,
                len(tracks),
            )

            await _cache_genre(
                redis,
                cache_key,
                tracks,
            )

            return tracks

    # fallback
    logger.warning(
        "genre chart fallback to search: %s",
        slug,
    )

    tracks = await search_tracks(
        genre,
        limit,
        redis=redis,
    )

    if tracks:
        await _cache_genre(redis, cache_key, tracks)
        return tracks

    return await get_chart_tracks(limit)


# ──────────────────────────────────────────────────────────────────────────────
# Global charts
# ──────────────────────────────────────────────────────────────────────────────


async def get_chart_tracks(limit: int = 100) -> list[dict]:
    try:
        data = await _get_json(
            "/chart/0/tracks",
            params={"limit": min(limit, 100)},
        )

        return [
            _map_track(item, i + 1)
            for i, item in enumerate(data.get("data") or [])
        ]

    except Exception:
        return []


# City → regional genre hints for blending city-specific flavor into charts
CITY_GENRE_HINTS: dict[str, list[str]] = {
    "dubai": ["electronic", "pop"],
    "abu dhabi": ["electronic", "pop"],
    "riyadh": ["pop", "r&b"],
    "doha": ["pop"],
    "muscat": ["pop"],
    "cairo": ["pop", "r&b"],
    "tokyo": ["k-pop", "pop"],
    "osaka": ["k-pop", "pop"],
    "seoul": ["k-pop", "pop"],
    "beijing": ["pop", "k-pop"],
    "shanghai": ["pop", "electronic"],
    "singapore": ["pop", "k-pop"],
    "bangkok": ["pop", "k-pop"],
    "jakarta": ["pop", "r&b"],
    "mumbai": ["pop", "indie"],
    "delhi": ["pop", "hip-hop"],
    "lagos": ["afrobeats", "r&b"],
    "nairobi": ["afrobeats", "pop"],
    "accra": ["afrobeats", "hip-hop"],
    "johannesburg": ["afrobeats", "hip-hop"],
    "mexico city": ["latin", "pop"],
    "bogota": ["latin", "hip-hop"],
    "sao paulo": ["latin", "pop"],
    "buenos aires": ["latin", "alternative"],
    "lima": ["latin", "pop"],
    "santiago": ["latin", "rock"],
    "miami": ["latin", "pop"],
    "new york": ["hip-hop", "r&b"],
    "los angeles": ["hip-hop", "pop"],
    "toronto": ["hip-hop", "r&b"],
    "chicago": ["hip-hop", "soul"],
    "houston": ["hip-hop", "r&b"],
    "atlanta": ["hip-hop", "r&b"],
    "london": ["pop", "indie"],
    "paris": ["pop", "electronic"],
    "berlin": ["electronic", "alternative"],
    "amsterdam": ["electronic", "pop"],
    "ibiza": ["electronic", "dance"],
    "madrid": ["latin", "pop"],
    "barcelona": ["latin", "pop"],
    "milan": ["pop", "electronic"],
    "rome": ["pop", "rock"],
    "sydney": ["pop", "indie"],
    "melbourne": ["indie", "pop"],
    "moscow": ["pop", "hip-hop"],
    "saint petersburg": ["indie", "alternative"],
    "astana": ["pop", "hip-hop"],
    "almaty": ["pop", "hip-hop"],
    "tashkent": ["pop", "hip-hop"],
    "bishkek": ["pop", "hip-hop"],
    "baku": ["pop", "electronic"],
    "tbilisi": ["pop", "electronic"],
    "istanbul": ["pop", "electronic"],
    "tel aviv": ["pop", "electronic"],
    "warsaw": ["pop", "electronic"],
    "kyiv": ["pop", "hip-hop"],
    "prague": ["rock", "pop"],
    "vienna": ["pop", "classical"],
    "stockholm": ["pop", "indie"],
    "oslo": ["pop", "indie"],
    "copenhagen": ["pop", "electronic"],
    "helsinki": ["pop", "metal"],
    "riga": ["pop", "electronic"],
    "vilnius": ["pop", "electronic"],
}

CITY_SEARCH_HINTS: dict[str, list[str]] = {
    "dubai": ["amr diab", "elissa", "nancy ajram", "arabic pop hits"],
    "abu dhabi": ["amr diab", "arabic pop hits"],
    "riyadh": ["mohammed عبده", "saudi pop", "arabic hits"],
    "doha": ["arabic hits", "middle east pop"],
    "cairo": ["amr diab", "tamer hosny", "egyptian pop"],
    "new york": ["kendrick lamar", "drake", "sza", "metro boomin"],
    "los angeles": ["billie eilish", "kendrick lamar", "tyler the creator"],
    "atlanta": ["future", "lil baby", "gunna", "21 savage"],
    "london": ["central cee", "dua lipa", "fred again", "skepta"],
    "paris": ["aya nakamura", "gims", "french pop"],
    "berlin": ["paula hartmann", "german electronic", "techno hits"],
    "amsterdam": ["martin garrix", "afrojack", "dance hits"],
    "ibiza": ["calvin harris", "swedish house mafia", "ibiza dance"],
    "tokyo": ["yoasobi", "ado", "j-pop hits"],
    "seoul": ["newjeans", "aespa", "bts", "k-pop hits"],
    "bangkok": ["thai pop", "k-pop hits", "milli"],
    "jakarta": ["indonesian pop", "raisa", "tiara andini"],
    "mumbai": ["bollywood hits", "arijit singh", "shreya ghoshal"],
    "delhi": ["bollywood hits", "badshah", "arijit singh"],
    "lagos": ["burna boy", "tems", "wizkid", "afrobeats hits"],
    "nairobi": ["afrobeats hits", "sauti sol", "bensoul"],
    "johannesburg": ["amapiano hits", "kabza de small", "tyla"],
    "mexico city": ["peso pluma", "latin hits", "carin leon"],
    "bogota": ["karol g", "feid", "latin hits"],
    "sao paulo": ["anitta", "luisa sonza", "brazil hits"],
    "buenos aires": ["bizarrap", "duki", "argentina hits"],
    "madrid": ["rosalia", "aitana", "spanish pop"],
    "barcelona": ["rosalia", "quevedo", "spanish hits"],
    "istanbul": ["turkish pop hits", "tarkan", "sezen aksu"],
    "astana": ["молданазар", "ninety one", "q-pop hits", "kazakh pop"],
    "almaty": ["молданазар", "ninety one", "dose", "kazakh pop"],
    "moscow": ["anna asti", "bearwolf", "russian pop hits"],
}


async def get_city_boost_tracks(city: str, limit: int = 20) -> list[dict]:
    city_lower = city.strip().lower()
    queries = CITY_SEARCH_HINTS.get(city_lower, [])
    if not queries:
        return []

    per_query = max(3, min(6, limit // max(len(queries), 1)))
    results = await asyncio.gather(
        *[search_tracks(query, limit=per_query) for query in queries],
        return_exceptions=True,
    )

    seen: set[str] = set()
    tracks: list[dict] = []
    for batch in results:
        if isinstance(batch, Exception) or not isinstance(batch, list):
            continue
        for track in batch:
            tid = track.get("deezer_id") or track.get("spotify_id")
            if tid and tid not in seen:
                seen.add(tid)
                tracks.append(track)
            if len(tracks) >= limit:
                return tracks[:limit]
    return tracks[:limit]


async def get_city_chart_tracks(city: str, limit: int = 20) -> list[dict]:
    """
    City-flavored charts using real Deezer data.
    Blends global chart with regional genre tracks for known cities.
    """
    city_lower = city.strip().lower()
    genre_hints = CITY_GENRE_HINTS.get(city_lower)
    city_boost = await get_city_boost_tracks(city, max(6, limit // 2))

    if not genre_hints and not city_boost:
        return await get_chart_tracks(limit)

    per_genre = max(limit // max(len(genre_hints or []), 1), 5)
    tasks = [get_chart_tracks(limit)]
    tasks.extend(get_genre_chart_tracks(g, per_genre) for g in (genre_hints or []))
    results = await asyncio.gather(*tasks, return_exceptions=True)

    seen: set[str] = set()
    tracks: list[dict] = []

    for t in city_boost:
        tid = t.get("deezer_id") or t.get("spotify_id")
        if tid and tid not in seen:
            seen.add(tid)
            tracks.append(t)

    for batch in results:
        if isinstance(batch, Exception) or not isinstance(batch, list):
            continue
        for t in batch:
            tid = t.get("deezer_id") or t.get("spotify_id")
            if tid and tid not in seen:
                seen.add(tid)
                tracks.append(t)
        if len(tracks) >= limit * 2:
            break

    return tracks[:limit]


# ──────────────────────────────────────────────────────────────────────────────
# Recommendations (нужен для spotify.py → get_recommendations)
# ──────────────────────────────────────────────────────────────────────────────

async def get_recommendation_tracks(
    seed_genres: list[str],
    mood_label: str | None = None,
    limit: int = 100,
    redis=None,
) -> list[dict]:
    """
    Рекомендации по жанрам через реальный Deezer Chart API.
    """
    if not seed_genres:
        return await get_chart_tracks(limit)

    seen: set[str] = set()
    tracks: list[dict] = []

    per_genre = max(limit // len(seed_genres), 5)

    results = await asyncio.gather(
        *[get_genre_chart_tracks(g, limit=per_genre, redis=redis) for g in seed_genres],
        return_exceptions=True,
    )

    for batch in results:
        if isinstance(batch, Exception):
            continue
        for t in batch:
            tid = t.get("deezer_id") or t.get("spotify_id")
            if tid and tid not in seen:
                seen.add(tid)
                tracks.append(t)

    tracks = tracks[:limit]
    if not tracks:
        tracks = await get_chart_tracks(limit)

    return tracks


# ──────────────────────────────────────────────────────────────────────────────
# Artists
# ──────────────────────────────────────────────────────────────────────────────


async def get_artist(deezer_artist_id: int) -> dict | None:
    # FIX: используем _put_artist_cache вместо прямой записи в dict
    if deezer_artist_id in _artist_cache:
        _artist_cache.move_to_end(deezer_artist_id)
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

    _put_artist_cache(deezer_artist_id, result)

    return result


async def get_artist_top_tracks(
    deezer_artist_id: int,
    limit: int = 50,
) -> list[dict]:
    try:
        data = await _get_json(
            f"/artist/{deezer_artist_id}/top",
            params={"limit": min(limit, 100)},
        )
    except Exception:
        return []

    items = data.get("data") or []
    return [_map_track(item, i + 1) for i, item in enumerate(items[:limit])]


async def get_artist_albums(
    deezer_artist_id: int,
    limit: int = 50,
) -> list[dict]:
    try:
        data = await _get_json(
            f"/artist/{deezer_artist_id}/albums",
            params={"limit": min(limit, 100)},
        )
    except Exception:
        return []

    albums: list[dict] = []
    for item in (data.get("data") or [])[:limit]:
        artist = item.get("artist") or {}
        albums.append({
            "id": str(item.get("id", "")),
            "title": item.get("title", ""),
            "artist": artist.get("name", ""),
            "artist_id": str(artist.get("id", "")),
            "cover_xl": item.get("cover_xl"),
            "cover_big": item.get("cover_big"),
            "cover_medium": item.get("cover_medium"),
            "cover_url": (
                item.get("cover_xl")
                or item.get("cover_big")
                or item.get("cover_medium")
            ),
            "nb_tracks": item.get("nb_tracks", 0),
            "release_date": item.get("release_date"),
            "record_type": item.get("record_type") or "album",
        })
    return albums


async def get_related_artists(
    deezer_artist_id: int,
    limit: int = 20,
) -> list[dict]:
    try:
        data = await _get_json(f"/artist/{deezer_artist_id}/related")
    except Exception:
        return []

    related: list[dict] = []
    for item in (data.get("data") or [])[:limit]:
        related.append({
            "id": item.get("id"),
            "name": item.get("name"),
            "picture_xl": item.get("picture_xl"),
            "picture_medium": item.get("picture_medium"),
            "nb_fan": item.get("nb_fan", 0),
            "nb_album": item.get("nb_album", 0),
        })
    return related


async def get_artist_radio(
    deezer_artist_id: int,
    limit: int = 25,
) -> list[dict]:
    try:
        data = await _get_json(
            f"/artist/{deezer_artist_id}/radio",
            params={"limit": min(limit, 100)},
        )
    except Exception:
        return []

    items = data.get("data") or []
    return [_map_track(item, i + 1) for i, item in enumerate(items[:limit])]


async def get_album_detail(deezer_album_id: int) -> dict | None:
    try:
        data = await _get_json(f"/album/{deezer_album_id}")
    except Exception:
        return None

    if not data or data.get("error"):
        return None

    artist = data.get("artist") or {}
    tracks_raw = ((data.get("tracks") or {}).get("data")) or []
    tracks = [_map_track(item, i + 1) for i, item in enumerate(tracks_raw)]

    return {
        "id": str(data.get("id", "")),
        "title": data.get("title", ""),
        "artist": artist.get("name", ""),
        "artist_id": artist.get("id"),
        "cover_xl": data.get("cover_xl"),
        "cover_big": data.get("cover_big"),
        "cover_medium": data.get("cover_medium"),
        "cover_url": (
            data.get("cover_xl")
            or data.get("cover_big")
            or data.get("cover_medium")
        ),
        "nb_tracks": data.get("nb_tracks", len(tracks)),
        "release_date": data.get("release_date"),
        "record_type": data.get("record_type") or "album",
        "tracks": tracks,
    }


async def get_album_tracks(
    deezer_album_id: int,
    limit: int = 100,
) -> list[dict]:
    album = await get_album_detail(deezer_album_id)
    if not album:
        return []
    return (album.get("tracks") or [])[:limit]


async def search_artist(query: str) -> dict | None:
    seen_ids: set[int] = set()
    candidates: list[dict] = []

    for q in [query, f'artist:"{query}"']:
        try:
            data = await _get_json(
                "/search/artist",
                params={"q": q, "limit": 10},
            )

        except Exception:
            continue

        for artist in data.get("data") or []:
            aid = artist.get("id")

            if not aid or aid in seen_ids:
                continue

            seen_ids.add(aid)
            candidates.append(artist)

    if not candidates:
        return None

    best = max(
        candidates,
        key=lambda artist: (
            _score_artist_name(
                artist.get("name", ""),
                query,
            ),
            int(artist.get("nb_fan", 0) or 0),
        ),
    )

    return {
        "id": best.get("id"),
        "name": best.get("name"),
        "picture_xl": best.get("picture_xl"),
        "nb_fan": best.get("nb_fan", 0),
    }


async def search_artists_list(
    query: str,
    limit: int = 10,
) -> list[dict]:
    seen_ids: set[int] = set()
    candidates: list[dict] = []

    for q in [query, f'artist:"{query}"']:
        try:
            data = await _get_json(
                "/search/artist",
                params={
                    "q": q,
                    "limit": min(limit * 5, 50),
                },
            )

        except Exception:
            continue

        for artist in data.get("data") or []:
            aid = artist.get("id")

            if not aid or aid in seen_ids:
                continue

            seen_ids.add(aid)
            candidates.append(artist)

    candidates.sort(
        key=lambda artist: (
            _score_artist_name(
                artist.get("name", ""),
                query,
            ),
            int(artist.get("nb_fan", 0) or 0),
        ),
        reverse=True,
    )

    return [
        {
            "id": artist.get("id"),
            "name": artist.get("name"),
            "picture_xl": artist.get("picture_xl"),
            "picture_medium": artist.get("picture_medium"),
            "nb_fan": artist.get("nb_fan", 0),
            "nb_album": artist.get("nb_album", 0),
        }
        for artist in candidates[:limit]
    ]
