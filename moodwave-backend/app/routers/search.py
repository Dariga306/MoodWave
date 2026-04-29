from __future__ import annotations

import asyncio
import logging
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import delete, desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_current_user_optional, get_db
from app.models.user import SearchHistory, User
from app.services import spotify as music_service
from app.services.search_service import (
    get_trending_searches,
    search_playlists_db,
    search_tracks_deezer,
    search_users_db,
    track_search_query,
)
from app.services.security import get_blocked_ids_for_user

logger = logging.getLogger(__name__)
router = APIRouter()

_BANNED_SUGGESTION_TERMS = (
    "official audio",
    "official song",
    "official songs",
    "lyrics",
    "lyric",
    "audio",
)


class SearchHistoryCreateRequest(BaseModel):
    query: str
    result_type: str = "track"
    result_id: str | None = None
    result_title: str | None = None
    result_cover: str | None = None


def _sanitize_suggestion(value: str) -> str:
    text = value.strip()
    lowered = text.lower()
    if not text:
        return ""
    if any(term in lowered for term in _BANNED_SUGGESTION_TERMS):
        return ""
    return text


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
    current_user: User | None = Depends(get_current_user_optional),
):
    redis = request.app.state.redis
    query = q.strip()

    if len(query) == 0:
        trending = await get_trending_searches(redis)
        return {"tracks": [], "users": [], "playlists": [], "trending": trending}

    await track_search_query(query, redis)

    requested_type = type.strip().lower() or "all"
    # For single-character queries only search tracks to avoid noise
    if len(query) == 1:
        want_tracks = True
        want_users = False
        want_playlists = False
    else:
        want_tracks = requested_type in ("all", "tracks")
        want_users = requested_type in ("all", "users")
        want_playlists = requested_type in ("all", "playlists")

    # Gather all searches in parallel
    blocked_ids = (
        await get_blocked_ids_for_user(db, current_user.id)
        if want_users and current_user is not None
        else []
    )

    async def _tracks():
        if not want_tracks:
            return []
        try:
            return await search_tracks_deezer(query, limit, redis)
        except Exception as exc:
            logger.warning("Track search error: %s", exc)
            return []

    async def _users():
        if not want_users or current_user is None:
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


@router.get(
    "/suggestions",
    summary="Get search autocomplete suggestions",
    description="Returns up to 8 autocomplete suggestions from user history and trending queries.",
)
async def get_search_suggestions(
    q: str = Query(default=""),
    limit: int = Query(default=8, ge=1, le=20),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = q.strip()
    if len(query) < 1:
        return []

    redis = request.app.state.redis
    suggestions: list[str] = []
    seen: set[str] = set()

    # From user's recent search history (prefix match)
    rows = (
        await db.execute(
            select(SearchHistory.query)
            .where(
                SearchHistory.user_id == current_user.id,
                SearchHistory.query.ilike(f"{query}%"),
            )
            .order_by(desc(SearchHistory.created_at))
            .limit(20)
        )
    ).scalars().all()
    for row in rows:
        cleaned = _sanitize_suggestion(row)
        if not cleaned:
            continue
        key = cleaned.lower()
        if key not in seen:
            seen.add(key)
            suggestions.append(cleaned)

    # From trending searches matching the prefix
    try:
        trending = await get_trending_searches(redis, limit=50)
        for t in trending:
            cleaned = _sanitize_suggestion(t)
            if not cleaned:
                continue
            key = cleaned.lower()
            if key not in seen and key.startswith(query.lower()):
                seen.add(key)
                suggestions.append(cleaned)
    except Exception:
        pass

    cleaned_query = _sanitize_suggestion(query)
    if cleaned_query and cleaned_query.lower() not in seen:
        suggestions.insert(0, cleaned_query)

    return suggestions[:limit]


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


@router.get(
    "/history",
    summary="Get recent searches",
    description="Returns the latest unique recent searches for the authenticated user.",
)
async def get_search_history(
    limit: int = Query(default=20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(SearchHistory)
            .where(SearchHistory.user_id == current_user.id)
            .order_by(desc(SearchHistory.created_at))
            .limit(100)
        )
    ).scalars().all()

    seen: set[tuple[str, str]] = set()
    result: list[dict] = []
    for row in rows:
        dedupe_key = (
            row.result_type or "track",
            row.result_id or row.query.strip().lower(),
        )
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        result.append(
            {
                "id": row.id,
                "query": row.query,
                "result_type": row.result_type,
                "result_id": row.result_id,
                "result_title": row.result_title,
                "result_cover": row.result_cover,
                "created_at": row.created_at.isoformat(),
            }
        )
        if len(result) >= limit:
            break
    return result


@router.post(
    "/history",
    status_code=200,
    summary="Save a recent search item",
    description="Stores a recent search item and keeps the list trimmed for the authenticated user.",
)
async def save_search_history(
    body: SearchHistoryCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = body.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail="query is required")

    item = SearchHistory(
        user_id=current_user.id,
        query=query,
        result_type=(body.result_type or "track").strip().lower(),
        result_id=body.result_id,
        result_title=body.result_title,
        result_cover=body.result_cover,
        created_at=datetime.utcnow(),
    )
    db.add(item)
    await db.flush()

    rows = (
        await db.execute(
            select(SearchHistory.id)
            .where(SearchHistory.user_id == current_user.id)
            .order_by(desc(SearchHistory.created_at))
            .offset(50)
        )
    ).scalars().all()
    if rows:
        await db.execute(delete(SearchHistory).where(SearchHistory.id.in_(rows)))

    await db.commit()
    return {"id": item.id, "message": "ok"}


@router.delete(
    "/history/{item_id}",
    status_code=200,
    summary="Delete one recent search item",
)
async def delete_search_history_item(
    item_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = await db.scalar(
        select(SearchHistory).where(
            SearchHistory.id == item_id,
            SearchHistory.user_id == current_user.id,
        )
    )
    if item is None:
        raise HTTPException(status_code=404, detail="History item not found")
    await db.delete(item)
    await db.commit()
    return {"message": "ok"}


@router.delete(
    "/history",
    status_code=200,
    summary="Clear all recent search items",
)
async def clear_search_history(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await db.execute(delete(SearchHistory).where(SearchHistory.user_id == current_user.id))
    await db.commit()
    return {"message": "ok"}
