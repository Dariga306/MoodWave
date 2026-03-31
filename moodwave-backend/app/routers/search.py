from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.services import spotify as music_service
from app.services.search_service import (
    get_trending_searches,
    search_playlists_db,
    search_tracks_itunes,
    search_users_db,
    track_search_query,
)
from app.services.security import get_blocked_ids_for_user

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# GET /search  — global search (tracks + users + playlists)
# ---------------------------------------------------------------------------

@router.get(
    "",
    summary="Global search",
    description="Searches tracks, users, and playlists in one request and returns trending queries when the search is empty.",
)
@router.get(
    "/",
    summary="Global search",
    description="Searches tracks, users, and playlists in one request and returns trending queries when the search is empty.",
)
async def global_search(
    q: str = Query(default=""),
    type: str = Query(default="all"),
    limit: int = Query(default=20, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    query = q.strip()

    if len(query) < 2:
        trending = await get_trending_searches(redis)
        return {"tracks": [], "users": [], "playlists": [], "trending": trending}

    await track_search_query(query, redis)

    requested_type = type.strip().lower() or "all"
    want_tracks = requested_type in ("all", "tracks")
    want_users = requested_type in ("all", "users")
    want_playlists = requested_type in ("all", "playlists")

    # Gather all searches in parallel
    blocked_ids = await get_blocked_ids_for_user(db, current_user.id) if want_users else []

    async def _tracks():
        if not want_tracks:
            return []
        try:
            return await search_tracks_itunes(query, limit, redis)
        except Exception as exc:
            logger.warning("Track search error: %s", exc)
            return []

    async def _users():
        if not want_users:
            return []
        return await search_users_db(query, current_user.id, blocked_ids, db, limit=10)

    async def _playlists():
        if not want_playlists:
            return []
        return await search_playlists_db(query, db, limit=10)

    tracks, users, playlists = await asyncio.gather(_tracks(), _users(), _playlists())

    return {"tracks": tracks, "users": users, "playlists": playlists}


# ---------------------------------------------------------------------------
# GET /search/trending  — no auth required
# ---------------------------------------------------------------------------

@router.get(
    "/trending",
    summary="Get trending searches",
    description="Returns the most popular recent search queries stored in Redis.",
)
async def trending_searches(
    limit: int = Query(default=10, ge=1, le=50),
    request: Request = None,
):
    redis = request.app.state.redis
    return await get_trending_searches(redis, limit)


# ---------------------------------------------------------------------------
# GET /search/playlists?q=  — playlist search
# ---------------------------------------------------------------------------

@router.get(
    "/playlists",
    summary="Search playlists",
    description="Searches public playlists by text query and returns ranked playlist matches.",
)
async def search_playlists(
    q: str = Query(default=""),
    limit: int = Query(default=10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = q.strip()
    if len(query) < 2:
        return []
    return await search_playlists_db(query, db, limit=limit)


# ---------------------------------------------------------------------------
# GET /search/users?q=  — user search
# ---------------------------------------------------------------------------

@router.get(
    "/users",
    summary="Search users",
    description="Searches public users by query while excluding blocked users and the current account.",
)
async def search_users(
    q: str = Query(default=""),
    limit: int = Query(default=10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = q.strip()
    if len(query) < 2:
        return []
    blocked_ids = await get_blocked_ids_for_user(db, current_user.id)
    return await search_users_db(query, current_user.id, blocked_ids, db, limit=limit)
