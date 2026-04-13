from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_current_user_optional, get_db
from app.models.music import ListeningHistory, TrackCache
from app.models.user import TasteVector, User, UserGenre
from app.schemas.music import TrackResponse
from app.services import cache as cache_svc
from app.services import deezer as deezer_service
from app.services import spotify as music_service
from app.services.matching import ACTION_WEIGHTS, update_taste_vector_for_user
from app.services.search_service import track_search_query

router = APIRouter()
artist_router = APIRouter(prefix="/artists")
album_router = APIRouter(prefix="/albums")

TRACK_SEARCH_CACHE_TTL = 300

# ---------------------------------------------------------------------------
# Fuzzy / multilingual search helpers
# ---------------------------------------------------------------------------

_ARTIST_CORRECTIONS: dict[str, str] = {
    # English typos / partial names
    "kani": "kanye west",
    "kanie": "kanye west",
    "kani west": "kanye west",
    "kanie west": "kanye west",
    "kany west": "kanye west",
    "kayne": "kanye west",
    "kayne west": "kanye west",
    "kanye": "kanye west",
    "emminem": "eminem",
    "emimem": "eminem",
    "eminm": "eminem",
    "draek": "drake",
    "beyonsay": "beyonce",
    "arian grande": "ariana grande",
    "billie eillish": "billie eilish",
    "billie eilsh": "billie eilish",
    "postmalone": "post malone",
    "nicky minaj": "nicki minaj",
    "jcole": "j. cole",
    "weeknd": "the weeknd",
    "the weekened": "the weeknd",
    "sheeran": "ed sheeran",
    # Russian → English (most common artist names)
    "кани вест": "kanye west",
    "канье вест": "kanye west",
    "канье": "kanye west",
    "дрейк": "drake",
    "уикенд": "the weeknd",
    "уикэнд": "the weeknd",
    "рианна": "rihanna",
    "риана": "rihanna",
    "эминем": "eminem",
    "тупак": "tupac",
    "бейонсе": "beyonce",
    "майкл джексон": "michael jackson",
    "тейлор свифт": "taylor swift",
    "ариана гранде": "ariana grande",
    "бруно марс": "bruno mars",
    "эд ширан": "ed sheeran",
    "билли айлиш": "billie eilish",
    "пост малон": "post malone",
    "джей зи": "jay-z",
    "карди би": "cardi b",
    "ники минаж": "nicki minaj",
    "кендрик ламар": "kendrick lamar",
    "трэвис скотт": "travis scott",
    "лил уэйн": "lil wayne",
    "джастин бибер": "justin bieber",
    "адель": "adele",
    "леди гага": "lady gaga",
    "кэти перри": "katy perry",
    "джей коул": "j. cole",
    "лил нас икс": "lil nas x",
    "лил нас": "lil nas x",
    "сиа": "sia",
    "халид": "khalid",
    "нас": "nas",
}

_CYR_TO_LAT: dict[str, str] = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo",
    "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
    "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
    "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch",
    "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
}


def _transliterate(text: str) -> str:
    return "".join(_CYR_TO_LAT.get(c, c) for c in text)


def _normalize_query(q: str) -> str:
    """Return the best search string: apply corrections dict first, then
    transliterate any remaining Cyrillic to Latin so external APIs find a match."""
    text = q.strip().lower()
    if text in _ARTIST_CORRECTIONS:
        return _ARTIST_CORRECTIONS[text]
    if any("\u0400" <= c <= "\u04FF" for c in text):
        return _transliterate(text)
    return text


RECOMMENDATIONS_CACHE_TTL = 3600
NOW_PLAYING_TTL = 600


class PlayTrackRequest(BaseModel):
    completion_pct: float = Field(default=0.0, ge=0.0, le=100.0)
    mood: Optional[str] = None
    title: Optional[str] = None
    artist: Optional[str] = None
    genre: Optional[str] = None


class LikeTrackRequest(BaseModel):
    action: str = Field(default="liked")
    title: Optional[str] = None
    artist: Optional[str] = None
    genre: Optional[str] = None


class SkipTrackRequest(BaseModel):
    time_listened_ms: int = Field(default=0, ge=0)
    title: Optional[str] = None
    artist: Optional[str] = None


def _extract_genres(track: Optional[TrackCache]) -> list[str]:
    if not track:
        return []
    if isinstance(track.genres, list):
        return [str(genre) for genre in track.genres if genre]
    return []


async def _invalidate_chart_caches(redis) -> None:
    try:
        keys = [key async for key in redis.scan_iter(match="charts:v2:city:*")]
        if keys:
            await redis.delete(*keys)
    except Exception:
        pass


async def _ensure_track_cached(
    db: AsyncSession,
    spotify_id: str,
    title: Optional[str],
    artist: Optional[str],
    genre: Optional[str],
) -> Optional[TrackCache]:
    """Return existing TrackCache or create a minimal one from body data."""
    track = await db.scalar(select(TrackCache).where(TrackCache.spotify_id == spotify_id))
    if track:
        return track
    if title and artist:
        track = TrackCache(
            spotify_id=spotify_id,
            title=title,
            artist=artist,
            genres=[genre] if genre else [],
            audio_features={},
        )
        db.add(track)
        await db.flush()
    return track


@router.get(
    "/me/recent",
    summary="Get recently played tracks",
    description="Returns the user's last N uniquely played tracks with cover art.",
)
async def get_recent_tracks(
    limit: int = Query(default=10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from sqlalchemy import desc, func as sa_func
    subq = (
        select(
            ListeningHistory.spotify_track_id,
            sa_func.max(ListeningHistory.created_at).label("last_played"),
        )
        .where(ListeningHistory.user_id == current_user.id)
        .group_by(ListeningHistory.spotify_track_id)
        .order_by(desc("last_played"))
        .limit(limit)
        .subquery()
    )
    rows = (
        await db.execute(
            select(TrackCache, subq.c.last_played)
            .join(subq, TrackCache.spotify_id == subq.c.spotify_track_id)
            .order_by(desc(subq.c.last_played))
        )
    ).all()
    return [
        {
            "spotify_id": track.spotify_id,
            "title": track.title,
            "artist": track.artist,
            "cover_url": track.cover_url,
            "duration_ms": track.duration_ms,
            "played_at": played_at.isoformat() if played_at else None,
        }
        for track, played_at in rows
    ]


@router.get(
    "/search",
    response_model=list[TrackResponse],
    summary="Search tracks",
    description="Searches tracks via Deezer (multilingual, typo-tolerant) and returns Deezer metadata including cover art and preview URLs.",
)
async def search_tracks(
    q: str = Query(default=""),
    limit: int = Query(default=20, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    query = q.strip()
    if len(query) < 1:
        return []

    normalized = _normalize_query(query)
    redis = request.app.state.redis
    cache_key = f"search:tracks:{normalized}:limit:{limit}"
    cached = await redis.get(cache_key)
    if cached:
        await track_search_query(normalized, redis)
        return json.loads(cached)

    try:
        api_query = normalized
        if len(normalized.strip()) < 3:
            api_query = normalized.strip() + " popular hits"

        attempts = [api_query]
        if api_query != normalized and normalized not in attempts:
            attempts.append(normalized)
        lowered = query.lower()
        if lowered not in attempts:
            attempts.append(lowered)

        tracks: list[dict] = []
        for candidate_query in attempts:
            tracks = await music_service.search_and_cache(candidate_query, limit, db)
            if tracks:
                break
    except Exception:
        fallback = await redis.get(cache_key)
        if fallback:
            return json.loads(fallback)
        raise HTTPException(status_code=503, detail="Track search service unavailable")

    await redis.setex(cache_key, TRACK_SEARCH_CACHE_TTL, json.dumps(tracks))
    await track_search_query(normalized, redis)
    return tracks


@router.get(
    "/charts",
    response_model=list[TrackResponse],
    summary="Get track charts",
    description="Returns chart-style track results filtered by genre when provided.",
)
async def get_charts(
    genre: str = Query(default=""),
    limit: int = Query(default=20, ge=1, le=50),
    current_user: User | None = Depends(get_current_user_optional),
):
    return await music_service.get_charts(genre or None, limit)


@router.get(
    "/recommendations",
    response_model=list[TrackResponse],
    summary="Get music recommendations",
    description="Builds personalized track recommendations from the user's taste vector with optional mood filtering.",
)
async def get_recommendations(
    mood: Optional[str] = Query(default=None),
    limit: int = Query(default=10, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    if current_user is None:
        tracks = await music_service.get_recommendations_from_spotify(
            seed_genres=[],
            seed_tracks=[],
            mood_label=mood,
            limit=limit,
        )
        if not tracks:
            tracks = await music_service.get_charts(limit=limit)
        return tracks

    redis = request.app.state.redis
    cache_key = f"recommendations:{current_user.id}:{(mood or '').lower()}:{limit}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    vector = tv.vector if tv and tv.vector else {}

    seed_genres = sorted(
        [
            (key.replace("genre:", ""), float(value))
            for key, value in vector.items()
            if key.startswith("genre:") and float(value) > 0
        ],
        key=lambda item: item[1],
        reverse=True,
    )
    top_genres = [item[0].replace("_", " ") for item in seed_genres[:3]]

    # Cold start: taste vector is empty → use genres selected during onboarding
    if not top_genres:
        user_genre_rows = (
            await db.execute(select(UserGenre).where(UserGenre.user_id == current_user.id))
        ).scalars().all()
        top_genres = [row.genre for row in user_genre_rows[:3]]

    tracks = await music_service.get_recommendations_from_spotify(
        seed_genres=top_genres,
        seed_tracks=[],
        mood_label=mood,
        limit=limit,
    )

    if not tracks:
        # Final fallback: globally trending if user has no genres either
        tracks = await music_service.get_charts(limit=limit)

    await redis.setex(cache_key, RECOMMENDATIONS_CACHE_TTL, json.dumps(tracks))
    return tracks


@router.get(
    "/{spotify_id}/youtube",
    summary="Get YouTube video ID for a track",
    description="Returns the YouTube video ID so the Flutter client can play the full track via YouTube.",
)
async def get_youtube_id(
    spotify_id: str,
    title: str = Query(default=""),
    artist: str = Query(default=""),
    request: Request = None,
    current_user: User | None = Depends(get_current_user_optional),
):
    from app.services.youtube_service import search_video_id

    redis = request.app.state.redis
    cache_key = f"yt:{spotify_id}"

    cached = await redis.get(cache_key)
    if cached:
        return {"video_id": cached, "track_id": spotify_id}

    video_id = await search_video_id(title, artist)

    if video_id:
        await redis.setex(cache_key, 86400, video_id)  # cache 24 h

    return {"video_id": video_id, "track_id": spotify_id}


@router.post(
    "/{spotify_id}/play",
    status_code=200,
    summary="Record track play",
    description="Stores a listening event, updates the user's taste vector, and refreshes now-playing activity in Redis.",
)
async def play_track(
    spotify_id: str,
    body: PlayTrackRequest = Body(default_factory=PlayTrackRequest),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    action = "completed" if body.completion_pct > 80 else "played"
    weight = float(ACTION_WEIGHTS[action])

    track = await _ensure_track_cached(db, spotify_id, body.title, body.artist, body.genre)
    genres = _extract_genres(track)

    db.add(
        ListeningHistory(
            user_id=current_user.id,
            spotify_track_id=spotify_id,
            action=action,
            weight=weight,
            completion_pct=body.completion_pct,
            mood=body.mood.lower() if body.mood else None,
        )
    )
    await db.commit()

    await update_taste_vector_for_user(
        db=db,
        redis=request.app.state.redis,
        user_id=current_user.id,
        spotify_track_id=spotify_id,
        action=action,
        genres=genres,
        mood=body.mood.lower() if body.mood else None,
    )
    await cache_svc.invalidate_recommendations(request.app.state.redis, current_user.id)
    await _invalidate_chart_caches(request.app.state.redis)

    now_playing = {
        "spotify_id": spotify_id,
        "title": track.title if track else (body.title or ""),
        "artist": track.artist if track else (body.artist or ""),
        "cover_url": track.cover_url if track else None,
        "played_at": datetime.now(timezone.utc).isoformat(),
    }
    await request.app.state.redis.setex(
        f"now_playing:{current_user.id}",
        NOW_PLAYING_TTL,
        json.dumps(now_playing),
    )
    return {"message": "ok", "action": action, "weight_applied": weight}


@router.post(
    "/{spotify_id}/like",
    status_code=200,
    summary="Like or dislike track",
    description="Records a positive or negative preference event for a track and updates recommendation signals.",
)
async def like_track(
    spotify_id: str,
    body: LikeTrackRequest = Body(default_factory=LikeTrackRequest),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    action = body.action.lower()
    if action not in {"liked", "disliked"}:
        raise HTTPException(status_code=400, detail="action must be liked or disliked")

    weight = float(ACTION_WEIGHTS[action])
    track = await _ensure_track_cached(db, spotify_id, body.title, body.artist, body.genre)
    genres = _extract_genres(track)

    db.add(
        ListeningHistory(
            user_id=current_user.id,
            spotify_track_id=spotify_id,
            action=action,
            weight=weight,
        )
    )
    await db.commit()

    await update_taste_vector_for_user(
        db=db,
        redis=request.app.state.redis,
        user_id=current_user.id,
        spotify_track_id=spotify_id,
        action=action,
        genres=genres,
    )
    await cache_svc.invalidate_recommendations(request.app.state.redis, current_user.id)
    return {"message": "ok", "weight_applied": weight}


@router.post(
    "/{spotify_id}/skip",
    status_code=200,
    summary="Skip track",
    description="Records a skip event for a track and updates the user's recommendation data.",
)
async def skip_track(
    spotify_id: str,
    body: SkipTrackRequest = Body(default_factory=SkipTrackRequest),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    action = "skipped_early" if body.time_listened_ms < 10000 else "skipped"
    weight = float(ACTION_WEIGHTS[action])

    track = await _ensure_track_cached(db, spotify_id, body.title, body.artist, None)
    genres = _extract_genres(track)

    db.add(
        ListeningHistory(
            user_id=current_user.id,
            spotify_track_id=spotify_id,
            action=action,
            weight=weight,
            time_listened_ms=body.time_listened_ms,
        )
    )
    await db.commit()

    await update_taste_vector_for_user(
        db=db,
        redis=request.app.state.redis,
        user_id=current_user.id,
        spotify_track_id=spotify_id,
        action=action,
        genres=genres,
    )
    await cache_svc.invalidate_recommendations(request.app.state.redis, current_user.id)
    return {"message": "ok", "action": action}


@artist_router.get(
    "/search",
    summary="Search artist profile",
    description="Looks up the closest Deezer artist match and returns the artist plus top tracks. Supports Cyrillic queries.",
)
async def search_artist_profile(
    q: str = Query(default=""),
    current_user: User | None = Depends(get_current_user_optional),
):
    query = q.strip()
    if len(query) < 1:
        return {"artist": None, "top_tracks": []}

    normalized = _normalize_query(query)
    artist = await deezer_service.search_artist(normalized)
    if not artist:
        return {"artist": None, "top_tracks": []}

    top_tracks = await deezer_service.get_artist_top_tracks(int(artist["id"]))
    return {"artist": artist, "top_tracks": top_tracks}


@artist_router.get(
    "/search/list",
    summary="Search multiple artists",
    description="Returns multiple Deezer artist matches for the query (up to 25). Supports Cyrillic queries.",
)
async def search_artists_list(
    q: str = Query(default=""),
    limit: int = Query(default=10, ge=1, le=25),
    current_user: User | None = Depends(get_current_user_optional),
):
    query = q.strip()
    if len(query) < 1:
        return []
    normalized = _normalize_query(query)
    return await deezer_service.search_artists_list(normalized, limit=limit)


@artist_router.get(
    "/{deezer_id}/profile",
    summary="Get artist profile",
    description="Returns Deezer artist metadata, top tracks, albums, and related artists.",
)
async def get_artist_profile(
    deezer_id: int,
    current_user: User | None = Depends(get_current_user_optional),
):
    artist, top_tracks, albums, related_artists = await asyncio.gather(
        deezer_service.get_artist(deezer_id),
        deezer_service.get_artist_top_tracks(deezer_id),
        deezer_service.get_artist_albums(deezer_id),
        deezer_service.get_related_artists(deezer_id),
    )
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")

    return {
        "artist": artist,
        "top_tracks": top_tracks,
        "albums": albums,
        "related_artists": related_artists,
    }


@album_router.get(
    "/search",
    summary="Search albums",
    description="Returns Deezer album matches for the query. Supports Cyrillic queries.",
)
async def search_albums(
    q: str = Query(default=""),
    limit: int = Query(default=10, ge=1, le=25),
    current_user: User | None = Depends(get_current_user_optional),
):
    query = q.strip()
    if len(query) < 1:
        return []
    normalized = _normalize_query(query)
    return await deezer_service.search_albums(normalized, limit=limit)


@album_router.get(
    "/{deezer_album_id}",
    summary="Get album detail",
    description="Returns album metadata and full track list from Deezer.",
)
async def get_album_detail(
    deezer_album_id: int,
    current_user: User | None = Depends(get_current_user_optional),
):
    album = await deezer_service.get_album_detail(deezer_album_id)
    if not album:
        raise HTTPException(status_code=404, detail="Album not found")
    return album


@album_router.get(
    "/{deezer_album_id}/tracks",
    summary="Get album tracks",
    description="Returns the track list for a Deezer album.",
)
async def get_album_tracks(
    deezer_album_id: int,
    current_user: User | None = Depends(get_current_user_optional),
):
    return await deezer_service.get_album_tracks(deezer_album_id)
