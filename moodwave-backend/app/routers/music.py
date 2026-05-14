from __future__ import annotations

import asyncio
import hashlib
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path as _FsPath
from typing import Optional

# File-based fallback cache for YouTube video IDs (used when Redis is unavailable)
_YT_CACHE_FILE = _FsPath(__file__).resolve().parents[2] / "tmp" / "yt_id_cache.json"
_yt_file_cache: dict[str, str] = {}

def _load_yt_cache() -> None:
    global _yt_file_cache
    try:
        if _YT_CACHE_FILE.exists():
            _yt_file_cache = json.loads(_YT_CACHE_FILE.read_text(encoding="utf-8"))
    except Exception:
        _yt_file_cache = {}

def _save_yt_cache(key: str, video_id: str) -> None:
    _yt_file_cache[key] = video_id
    try:
        _YT_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        _YT_CACHE_FILE.write_text(json.dumps(_yt_file_cache), encoding="utf-8")
    except Exception:
        pass

_load_yt_cache()

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import and_, asc, desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_current_user_optional, get_db
from app.models.music import LikedAlbum, ListeningHistory, TrackCache
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
    # Russian / CIS artists (Cyrillic native names → Deezer-searchable)
    "кино": "Kino",
    "цой": "Kino",
    "виктор цой": "Kino",
    "земфира": "Zemfira",
    "земфира рамазанова": "Zemfira",
    "гречка": "Grechka",
    "монеточка": "Monetochka",
    "ic3peak": "IC3PEAK",
    "айс пик": "IC3PEAK",
    "shortparis": "Shortparis",
    "шортпарис": "Shortparis",
    "аигел": "Aigel",
    "аигел гайсина": "Aigel",
    "сплин": "Splin",
    "наутилус помпилиус": "Nautilus Pompilius",
    "наутилус": "Nautilus Pompilius",
    "агата кристи": "Agata Kristi",
    "би-2": "Bi-2",
    "би 2": "Bi-2",
    "чиж": "Chizh",
    "чиж и ко": "Chizh",
    "ленинград": "Leningrad",
    "шнуров": "Leningrad",
    "ддт": "DDT",
    "юрий шевчук": "DDT",
    "алиса": "Alisa",
    "кинчев": "Alisa",
    "пикник": "Piknik",
    "аукцыон": "Auktsyon",
    "жуки": "Zhuki",
    "мумий тролль": "Mumiy Troll",
    "мумий": "Mumiy Troll",
    "лагутенко": "Mumiy Troll",
    "ляпис трубецкой": "Lyapis Trubetskoy",
    "ляпис": "Lyapis Trubetskoy",
    "тату": "t.A.T.u.",
    "тату": "t.A.T.u.",
    "нервы": "Nervy",
    "gone.fludd": "gone.fludd",
    "фейс": "Face",
    "элджей": "Eljay",
    "niletto": "Niletto",
    "нилетто": "Niletto",
    "клава кока": "Klava Koka",
    "клава": "Klava Koka",
    "morgenshtern": "Morgenshtern",
    "морген": "Morgenshtern",
    "morgenstern": "Morgenshtern",
    "оксимирон": "Oxxxymiron",
    "oxxxymiron": "Oxxxymiron",
    "баста": "Basta",
    "ноггано": "Noggano",
    "тимати": "Timati",
    "скриптонит": "Scriptonite",
    "scriptonite": "Scriptonite",
    "jah khalib": "Jah Khalib",
    "джа халиб": "Jah Khalib",
    "мот": "Mot",
    "ханза": "Hanza",
    "макс корж": "Max Korzh",
    "корж": "Max Korzh",
    "ария": "Aria",
    "ария рок": "Aria",
    "король и шут": "Korol i Shut",
    "кис": "Korol i Shut",
    "порнофильмы": "Pornophilms",
    "рубль": "Rubl",
    # Kazakh artists
    "imanbek": "Imanbek",
    "иманбек": "Imanbek",
    "moldanazar": "Moldanazar",
    "молданазар": "Moldanazar",
    "dimash": "Dimash",
    "димаш": "Dimash",
    "dimash kudaibergen": "Dimash",
    "димаш кудайберген": "Dimash",
}

def _normalize_query(q: str) -> str:
    """Return the best search string.
    Known artist aliases/corrections are applied from the dict.
    All other queries (including Cyrillic) are passed as-is — Deezer has native
    multilingual search and handles Cyrillic, Arabic, Japanese, etc. directly."""
    text = q.strip().lower()
    if text in _ARTIST_CORRECTIONS:
        return _ARTIST_CORRECTIONS[text]
    return q.strip()


RECOMMENDATIONS_CACHE_TTL = 3600
NOW_PLAYING_TTL = 600


class PlayTrackRequest(BaseModel):
    completion_pct: float = Field(default=0.0, ge=0.0, le=100.0)
    mood: Optional[str] = None
    title: Optional[str] = None
    artist: Optional[str] = None
    genre: Optional[str] = None
    cover_url: Optional[str] = None


class LikeTrackRequest(BaseModel):
    action: str = Field(default="liked")
    title: Optional[str] = None
    artist: Optional[str] = None
    genre: Optional[str] = None


class SkipTrackRequest(BaseModel):
    time_listened_ms: int = Field(default=0, ge=0)
    title: Optional[str] = None
    artist: Optional[str] = None


class ProgressUpdateRequest(BaseModel):
    progress_ms: int = Field(default=0, ge=0)
    completed: bool = False
    title: Optional[str] = None
    artist: Optional[str] = None
    cover_url: Optional[str] = None


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
    cover_url: Optional[str] = None,
) -> Optional[TrackCache]:
    """Return existing TrackCache or create/update a minimal one from body data."""
    track = await db.scalar(select(TrackCache).where(TrackCache.spotify_id == spotify_id))
    if track:
        # Update cover_url if it was missing and we now have it
        if cover_url and not track.cover_url:
            track.cover_url = cover_url
        return track
    if title:
        track = TrackCache(
            spotify_id=spotify_id,
            title=title,
            artist=artist or "",
            cover_url=cover_url,
            genres=[genre] if genre else [],
            audio_features={},
        )
        db.add(track)
        await db.flush()
    return track


@router.get(
    "/me/history",
    summary="Get listening history grouped by day",
    description="Returns the user's full listening history grouped into day sections (Today, Yesterday, or locale date).",
)
async def get_listening_history(
    limit: int = Query(default=150, ge=1, le=300),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(ListeningHistory, TrackCache)
            .join(TrackCache, TrackCache.spotify_id == ListeningHistory.spotify_track_id, isouter=True)
            .where(ListeningHistory.user_id == current_user.id)
            .order_by(desc(ListeningHistory.created_at))
            .limit(limit)
        )
    ).all()

    today = datetime.utcnow().date()
    yesterday = today - timedelta(days=1)

    grouped: dict[str, list[dict]] = {}
    for history, track in rows:
        if track is None:
            continue
        event_date = history.created_at.date()
        if event_date == today:
            label = "Today"
        elif event_date == yesterday:
            label = "Yesterday"
        else:
            raw = history.created_at.strftime("%d %b %Y")
            label = raw.lstrip("0")  # → "9 Apr"

        if label not in grouped:
            grouped[label] = []
        grouped[label].append({
            "spotify_id": track.spotify_id,
            "title": track.title,
            "artist": track.artist,
            "album": track.album,
            "cover_url": track.cover_url,
            "preview_url": track.preview_url or None,
            "duration_ms": track.duration_ms,
            "played_at": history.created_at.isoformat() + "Z",
            "action": history.action.value,
        })

    return [{"date": label, "tracks": tracks} for label, tracks in grouped.items()]


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
    subq = (
        select(
            ListeningHistory.spotify_track_id,
            func.max(ListeningHistory.created_at).label("last_played"),
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
            "album": track.album,
            "cover_url": track.cover_url,
            "preview_url": track.preview_url or None,
            "duration_ms": track.duration_ms,
            "played_at": (played_at.isoformat() + "Z") if played_at else None,
        }
        for track, played_at in rows
    ]


@router.get(
    "/me/liked",
    summary="Get liked tracks",
    description="Returns tracks the user has liked, deduplicated, most recently liked first.",
)
async def get_liked_tracks(
    limit: int = Query(default=100, ge=1, le=300),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from sqlalchemy import desc as sa_desc, func as sa_func

    subq = (
        select(
            ListeningHistory.spotify_track_id,
            sa_func.max(ListeningHistory.created_at).label("last_action_at"),
        )
        .where(
            ListeningHistory.user_id == current_user.id,
            ListeningHistory.action.in_(("liked", "disliked")),
        )
        .group_by(ListeningHistory.spotify_track_id)
        .order_by(sa_desc("last_action_at"))
        .limit(limit)
        .subquery()
    )
    rows = (
        await db.execute(
            select(TrackCache, ListeningHistory.created_at)
            .join(subq, TrackCache.spotify_id == subq.c.spotify_track_id)
            .join(
                ListeningHistory,
                and_(
                    ListeningHistory.spotify_track_id == subq.c.spotify_track_id,
                    ListeningHistory.created_at == subq.c.last_action_at,
                    ListeningHistory.user_id == current_user.id,
                ),
            )
            .where(ListeningHistory.action == "liked")
            .order_by(sa_desc(ListeningHistory.created_at))
        )
    ).all()
    return [
        {
            "spotify_id": track.spotify_id,
            "title": track.title,
            "artist": track.artist,
            "album": track.album,
            "cover_url": track.cover_url,
            "preview_url": track.preview_url or None,
            "duration_ms": track.duration_ms,
            "liked_at": liked_at.isoformat() if liked_at else None,
        }
        for track, liked_at in rows
    ]


@router.get(
    "/me/on-repeat",
    summary="Get on-repeat tracks",
    description="Returns the user's most-played tracks in the last 30 days.",
)
async def get_on_repeat_tracks(
    limit: int = Query(default=20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    rows = (
        await db.execute(
            select(
                ListeningHistory.spotify_track_id,
                func.count().label("play_count"),
                func.max(ListeningHistory.created_at).label("last_played"),
            )
            .where(ListeningHistory.user_id == current_user.id)
            .where(ListeningHistory.created_at >= cutoff)
            .group_by(ListeningHistory.spotify_track_id)
            .order_by(desc("play_count"), desc("last_played"))
            .limit(limit)
        )
    ).all()

    track_ids = [row.spotify_track_id for row in rows]
    if not track_ids:
        # Fall back to global recommendations when no history yet
        return await music_service.get_recommendations_from_spotify(None, limit)

    tracks = (
        await db.execute(select(TrackCache).where(TrackCache.spotify_id.in_(track_ids)))
    ).scalars().all()
    track_map = {t.spotify_id: t for t in tracks}
    result = []
    row_map = {row.spotify_track_id: row for row in rows}
    for tid in track_ids:
        t = track_map.get(tid)
        row = row_map.get(tid)
        if t:
            result.append({
                "spotify_id": t.spotify_id,
                "title": t.title,
                "artist": t.artist,
                "cover_url": t.cover_url,
                "preview_url": t.preview_url,
                "duration_ms": t.duration_ms,
                "play_count": int(row.play_count) if row else 0,
                "last_played": row.last_played.isoformat() if row and row.last_played else None,
            })
    return result


@router.get(
    "/me/flashbacks",
    summary="Get flashback tracks",
    description="Returns tracks the user played 60+ days ago but not in the last 30 days.",
)
async def get_flashback_tracks(
    limit: int = Query(default=20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    recent_cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    old_cutoff = datetime.now(timezone.utc) - timedelta(days=60)

    recent_ids_sq = (
        select(ListeningHistory.spotify_track_id)
        .where(ListeningHistory.user_id == current_user.id)
        .where(ListeningHistory.created_at >= recent_cutoff)
        .distinct()
        .scalar_subquery()
    )

    rows = (
        await db.execute(
            select(
                ListeningHistory.spotify_track_id,
                func.count().label("play_count"),
                func.max(ListeningHistory.created_at).label("last_played"),
            )
            .where(ListeningHistory.user_id == current_user.id)
            .where(ListeningHistory.created_at <= old_cutoff)
            .where(ListeningHistory.spotify_track_id.not_in(recent_ids_sq))
            .group_by(ListeningHistory.spotify_track_id)
            .order_by(asc("last_played"), desc("play_count"))
            .limit(limit)
        )
    ).all()

    track_ids = [row.spotify_track_id for row in rows]
    if not track_ids:
        return await music_service.get_recommendations_from_spotify(None, limit)

    tracks = (
        await db.execute(select(TrackCache).where(TrackCache.spotify_id.in_(track_ids)))
    ).scalars().all()
    track_map = {t.spotify_id: t for t in tracks}
    result = []
    row_map = {row.spotify_track_id: row for row in rows}
    for tid in track_ids:
        t = track_map.get(tid)
        row = row_map.get(tid)
        if t:
            result.append({
                "spotify_id": t.spotify_id,
                "title": t.title,
                "artist": t.artist,
                "cover_url": t.cover_url,
                "preview_url": t.preview_url,
                "duration_ms": t.duration_ms,
                "play_count": int(row.play_count) if row else 0,
                "last_played": row.last_played.isoformat() if row and row.last_played else None,
            })
    return result


@router.get(
    "/me/genre-mixes",
    summary="Get genre mixes",
    description="Builds lightweight personalized genre mixes from the user's listening history and saved genres.",
)
async def get_genre_mixes(
    limit: int = Query(default=6, ge=1, le=12),
    tracks_per_mix: int = Query(default=12, ge=5, le=30),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    preferred_genres = (
        await db.execute(
            select(UserGenre.genre)
            .where(UserGenre.user_id == current_user.id)
            .order_by(desc(UserGenre.weight))
            .limit(limit)
        )
    ).scalars().all()

    if not preferred_genres:
        return []

    listening_rows = (
        await db.execute(
            select(TrackCache, func.count(ListeningHistory.id).label("play_count"))
            .join(ListeningHistory, ListeningHistory.spotify_track_id == TrackCache.spotify_id)
            .where(ListeningHistory.user_id == current_user.id)
            .group_by(TrackCache.id)
            .order_by(desc("play_count"), desc(func.max(ListeningHistory.created_at)))
            .limit(400)
        )
    ).all()

    mixes: list[dict] = []
    used_track_ids: set[str] = set()
    for genre in preferred_genres:
        genre_key = genre.lower()
        genre_tracks: list[dict] = []
        for track, play_count in listening_rows:
            track_genres = [g.lower() for g in (track.genres or []) if isinstance(g, str)]
            if genre_key not in track_genres or track.spotify_id in used_track_ids:
                continue
            genre_tracks.append({
                "spotify_id": track.spotify_id,
                "title": track.title,
                "artist": track.artist,
                "cover_url": track.cover_url,
                "preview_url": track.preview_url,
                "duration_ms": track.duration_ms,
                "play_count": int(play_count or 0),
            })
            used_track_ids.add(track.spotify_id)
            if len(genre_tracks) >= tracks_per_mix:
                break

        if not genre_tracks:
            continue

        mixes.append({
            "id": genre_key.replace(" ", "_"),
            "title": f"{genre.title()} Mix",
            "subtitle": f"{len(genre_tracks)} tracks built from your taste",
            "genre": genre,
            "cover_url": genre_tracks[0]["cover_url"],
            "tracks": genre_tracks,
        })

    return mixes


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
    redis = getattr(request.app.state, "redis", None) if request is not None else None
    cache_key = f"search:tracks:{normalized}:limit:{limit}"
    cached = None
    if redis is not None:
        try:
            cached = await redis.get(cache_key)
        except Exception:
            cached = None
    if cached:
        if redis is not None:
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
        fallback = None
        if redis is not None:
            try:
                fallback = await redis.get(cache_key)
            except Exception:
                fallback = None
        if fallback:
            return json.loads(fallback)
        raise HTTPException(status_code=503, detail="Track search service unavailable")

    if redis is not None:
        try:
            await redis.setex(cache_key, TRACK_SEARCH_CACHE_TTL, json.dumps(tracks))
        except Exception:
            pass
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
    summary="Get full audio URL for a track via yt-dlp",
    description="Downloads audio via yt-dlp and returns a local server URL that just_audio can stream reliably.",
)
async def get_youtube_id(
    spotify_id: str,
    title: str = Query(default=""),
    artist: str = Query(default=""),
    request: Request = None,
    current_user: User | None = Depends(get_current_user_optional),
):
    from pathlib import Path as FsPath
    from app.services.youtube_service import search_video_id

    redis = request.app.state.redis
    signature = f"{spotify_id}|{title.strip().lower()}|{artist.strip().lower()}"
    cache_suffix = hashlib.md5(signature.encode("utf-8")).hexdigest()
    vid_cache_key = f"yt_id:{cache_suffix}"

    # 1. Get video ID — try Redis, then file cache, then yt-dlp search
    video_id: str | None = None
    try:
        video_id = await redis.get(vid_cache_key)
    except Exception:
        pass

    if not video_id:
        video_id = _yt_file_cache.get(cache_suffix)

    if not video_id:
        video_id = await search_video_id(title, artist)
        if video_id:
            try:
                await redis.setex(vid_cache_key, 604800, video_id)
            except Exception:
                pass
            _save_yt_cache(cache_suffix, video_id)

    if not video_id:
        return {"video_id": None, "stream_url": None, "track_id": spotify_id}

    return {"video_id": video_id, "stream_url": None, "track_id": spotify_id}


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

    track = await _ensure_track_cached(db, spotify_id, body.title, body.artist, body.genre, body.cover_url)
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
        "cover_url": (track.cover_url if track else None) or body.cover_url,
        "played_at": datetime.now(timezone.utc).isoformat(),
    }
    redis = request.app.state.redis
    await redis.setex(
        f"now_playing:{current_user.id}",
        NOW_PLAYING_TTL,
        json.dumps(now_playing),
    )

    # Update trending sorted sets
    city_key = (getattr(current_user, "city", None) or "unknown").lower().replace(" ", "_")
    today_key = f"trending:snapshot:{datetime.now(timezone.utc).strftime('%Y%m%d')}"
    await redis.zincrby("trending:global", 1, spotify_id)
    await redis.zincrby(f"trending:city:{city_key}", 1, spotify_id)
    await redis.zincrby(today_key, 1, spotify_id)
    await redis.expire(today_key, 172800)  # keep 2 days

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
        deezer_service.get_artist_top_tracks(deezer_id, limit=50),
        deezer_service.get_artist_albums(deezer_id, limit=50),
        deezer_service.get_related_artists(deezer_id),
    )
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")

    seen_ids: set[str] = {str(t.get("spotify_id") or t.get("deezer_id") or "") for t in top_tracks if t.get("spotify_id") or t.get("deezer_id")}

    # Pad with radio tracks when top_tracks is sparse (< 20)
    if len(top_tracks) < 20:
        try:
            radio_tracks = await deezer_service.get_artist_radio(deezer_id, limit=25)
            for t in radio_tracks:
                tid = str(t.get("spotify_id") or t.get("deezer_id") or "")
                if tid and tid not in seen_ids:
                    seen_ids.add(tid)
                    top_tracks.append(t)
        except Exception:
            pass

    # Fallback when the /top endpoint returns nothing (common for K-pop solo artists, etc.)
    if not top_tracks:
        fallback: list[dict] = []
        if albums:
            album_ids = [int(a["id"]) for a in albums[:4] if a.get("id")]
            if album_ids:
                album_results = await asyncio.gather(
                    *[deezer_service.get_album_detail(aid) for aid in album_ids],
                    return_exceptions=True,
                )
                for res in album_results:
                    if isinstance(res, dict):
                        for t in res.get("tracks") or []:
                            tid = str(t.get("spotify_id") or t.get("deezer_id") or "")
                            if tid and tid not in seen_ids:
                                seen_ids.add(tid)
                                fallback.append(t)
        if not fallback:
            fallback = await deezer_service.search_tracks(artist["name"], limit=50)
        top_tracks = fallback[:50]

    return {
        "artist": artist,
        "top_tracks": top_tracks[:50],
        "albums": albums,
        "related_artists": related_artists,
    }


@artist_router.get(
    "/{deezer_id}/discography",
    summary="Get full artist discography",
    description="Returns all releases grouped by type: albums, singles, eps, others.",
)
async def get_artist_discography(
    deezer_id: int,
    current_user: User | None = Depends(get_current_user_optional),
):
    all_releases = await deezer_service.get_artist_albums(deezer_id, limit=100)
    by_type: dict[str, list] = {"albums": [], "singles": [], "eps": [], "others": []}
    for release in all_releases:
        rtype = (release.get("record_type") or "album").lower()
        if rtype == "album":
            by_type["albums"].append(release)
        elif rtype == "single":
            by_type["singles"].append(release)
        elif rtype in ("ep", "ep_release"):
            by_type["eps"].append(release)
        else:
            by_type["others"].append(release)
    return by_type


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
    "/liked",
    summary="Get liked albums",
    description="Returns the authenticated user's saved albums ordered by most recently saved.",
)
async def get_liked_albums(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(LikedAlbum)
            .where(LikedAlbum.user_id == current_user.id)
            .order_by(desc(LikedAlbum.liked_at), desc(LikedAlbum.id))
        )
    ).scalars().all()
    return [
        {
            "id": row.album_id,
            "album_name": row.album_name,
            "artist_name": row.artist_name,
            "cover_url": row.cover_url,
            "liked_at": row.liked_at.isoformat() if row.liked_at else None,
        }
        for row in rows
    ]


class LikeAlbumRequest(BaseModel):
    album_id: str = Field(min_length=1, max_length=100)
    album_name: str = Field(min_length=1, max_length=255)
    artist_name: str = Field(default="", max_length=255)
    cover_url: Optional[str] = None


@album_router.get(
    "/{album_id}/liked-status",
    summary="Get album liked status",
    description="Returns whether the authenticated user has saved this album.",
)
async def get_album_liked_status(
    album_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    row = await db.scalar(
        select(LikedAlbum).where(
            LikedAlbum.user_id == current_user.id,
            LikedAlbum.album_id == album_id,
        )
    )
    return {"liked": row is not None}


@album_router.post(
    "/{album_id}/like",
    summary="Save album to library",
    description="Stores an album in the authenticated user's library.",
)
async def like_album(
    album_id: str,
    body: LikeAlbumRequest = Body(default_factory=LikeAlbumRequest),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    saved = await db.scalar(
        select(LikedAlbum).where(
            LikedAlbum.user_id == current_user.id,
            LikedAlbum.album_id == album_id,
        )
    )
    if saved is None:
        db.add(
            LikedAlbum(
                user_id=current_user.id,
                album_id=album_id,
                album_name=body.album_name.strip(),
                artist_name=body.artist_name.strip(),
                cover_url=body.cover_url,
            )
        )
        await db.commit()
    return {"liked": True}


@album_router.delete(
    "/{album_id}/like",
    summary="Remove album from library",
    description="Removes an album from the authenticated user's library.",
)
async def unlike_album(
    album_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    row = await db.scalar(
        select(LikedAlbum).where(
            LikedAlbum.user_id == current_user.id,
            LikedAlbum.album_id == album_id,
        )
    )
    if row is not None:
        await db.delete(row)
        await db.commit()
    return {"liked": False}


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



@router.post(
    "/{spotify_id}/progress",
    status_code=200,
    summary="Update track progress",
    description="Heartbeat endpoint called every 5s during playback to save listening position.",
)
async def update_track_progress(
    spotify_id: str,
    body: ProgressUpdateRequest = Body(default_factory=ProgressUpdateRequest),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Update most recent listening history entry for this user+track
    from sqlalchemy import update as sa_update
    latest = await db.scalar(
        select(ListeningHistory)
        .where(
            ListeningHistory.user_id == current_user.id,
            ListeningHistory.spotify_track_id == spotify_id,
        )
        .order_by(desc(ListeningHistory.created_at))
        .limit(1)
    )
    if latest:
        latest.time_listened_ms = body.progress_ms
    track = await db.scalar(select(TrackCache).where(TrackCache.spotify_id == spotify_id))
    if not track and (body.title or body.artist or body.cover_url):
        track = await _ensure_track_cached(
            db,
            spotify_id,
            body.title,
            body.artist,
            None,
            body.cover_url,
        )
    elif track and body.cover_url and not track.cover_url:
        track.cover_url = body.cover_url
    if request is not None and not body.completed:
        previous = None
        try:
            raw_previous = await request.app.state.redis.get(f"now_playing:{current_user.id}")
            previous = json.loads(raw_previous) if raw_previous else None
        except Exception:
            previous = None
        previous_cover = (
            previous.get("cover_url")
            or previous.get("track_cover_url")
            or previous.get("album_cover_url")
            if isinstance(previous, dict)
            else None
        )
        now_playing = {
            "spotify_id": spotify_id,
            "title": (track.title if track else "") or body.title or (previous.get("title") if isinstance(previous, dict) else ""),
            "artist": (track.artist if track else "") or body.artist or (previous.get("artist") if isinstance(previous, dict) else ""),
            "cover_url": (track.cover_url if track else None) or body.cover_url or previous_cover,
            "track_cover_url": (track.cover_url if track else None) or body.cover_url or previous_cover,
            "played_at": datetime.now(timezone.utc).isoformat(),
        }
        await request.app.state.redis.setex(
            f"now_playing:{current_user.id}",
            NOW_PLAYING_TTL,
            json.dumps(now_playing),
        )
    await db.commit()
    return {"ok": True}
