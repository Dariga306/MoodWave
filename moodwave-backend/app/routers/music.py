from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
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
    description="Searches tracks through the music provider, caches results, and records the query for trending searches.",
)
async def search_tracks(
    q: str = Query(default=""),
    limit: int = Query(default=20, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = q.strip()
    if len(query) < 1:
        return []

    redis = request.app.state.redis
    cache_key = f"search:tracks:{query.lower()}:limit:{limit}"
    cached = await redis.get(cache_key)
    if cached:
        await track_search_query(query, redis)
        return json.loads(cached)

    try:
        tracks = await music_service.search_and_cache(query, limit, db)
    except Exception:
        fallback = await redis.get(cache_key)
        if fallback:
            return json.loads(fallback)
        raise HTTPException(status_code=503, detail="Track search service unavailable")

    await redis.setex(cache_key, TRACK_SEARCH_CACHE_TTL, json.dumps(tracks))
    await track_search_query(query, redis)
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
    current_user: User = Depends(get_current_user),
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
    current_user: User = Depends(get_current_user),
):
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
    current_user: User = Depends(get_current_user),
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
    body: PlayTrackRequest,
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
    body: LikeTrackRequest,
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
    body: SkipTrackRequest,
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
    description="Looks up the closest Deezer artist match and returns the artist plus top tracks.",
)
async def search_artist_profile(
    q: str = Query(default=""),
    current_user: User = Depends(get_current_user),
):
    query = q.strip()
    if len(query) < 1:
        return {"artist": None, "top_tracks": []}

    artist = await deezer_service.search_artist(query)
    if not artist:
        return {"artist": None, "top_tracks": []}

    top_tracks = await deezer_service.get_artist_top_tracks(int(artist["id"]))
    return {"artist": artist, "top_tracks": top_tracks}


@artist_router.get(
    "/{deezer_id}/profile",
    summary="Get artist profile",
    description="Returns Deezer artist metadata, top tracks, albums, and related artists.",
)
async def get_artist_profile(
    deezer_id: int,
    current_user: User = Depends(get_current_user),
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
    "/{deezer_album_id}",
    summary="Get album detail",
    description="Returns album metadata and full track list from Deezer.",
)
async def get_album_detail(
    deezer_album_id: int,
    current_user: User = Depends(get_current_user),
):
    album = await deezer_service.get_album_detail(deezer_album_id)
    if not album:
        raise HTTPException(status_code=404, detail="Album not found")
    return album
