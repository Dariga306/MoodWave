"""
search_service.py — Search logic: Deezer API, user/playlist DB queries, Redis trending.

ИСПРАВЛЕНИЯ:
  1. search_tracks_deezer: ключ кэша теперь включает limit (было без limit — разные
     запросы с разным limit читали один и тот же кэш с неправильным количеством).
  2. search_tracks_deezer: redis передаётся в deezer_service.search_tracks, чтобы
     deezer тоже мог читать/писать свой кэш.
  3. search_users_db: добавлен ORDER BY — точные совпадения идут первыми,
     потом prefix-совпадения, потом contains. Без ORDER BY PostgreSQL возвращал
     строки в heap-order, точное совпадение могло быть последним.
  4. search_playlists_db: аналогичный ORDER BY по title.
"""
from __future__ import annotations

import json
import logging

from sqlalchemy import and_, case, func, or_, select, true
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.music import Playlist, PlaylistVisibility
from app.models.user import User
from app.services import deezer as deezer_service

logger = logging.getLogger(__name__)

TRACK_CACHE_TTL = 300    # 5 minutes
TRENDING_TTL = 86400     # 24 hours
TRENDING_KEY = "search:trending:daily"

# Максимальное количество записей в истории поиска
SEARCH_HISTORY_MAX = 50


# ---------------------------------------------------------------------------
# Deezer track search with Redis cache
# ---------------------------------------------------------------------------

async def search_tracks_deezer(q: str, limit: int = 20, redis=None) -> list[dict]:
    """
    Search tracks via Deezer service.

    Кэширование происходит внутри deezer_service.search_tracks,
    поэтому здесь Redis не трогаем.
    """
    try:
        return await deezer_service.search_tracks(q, limit, redis=redis)
    except Exception as exc:
        logger.warning("Deezer search failed for '%s': %s", q, exc)
        return []

# ---------------------------------------------------------------------------
# DB searches (async, using SQLAlchemy async sessions)
# ---------------------------------------------------------------------------

async def search_users_db(
    q: str,
    current_user_id: int,
    blocked_ids: list[int],
    db: AsyncSession,
    limit: int = 10,
) -> list[dict]:
    """Search public active users by username / first_name / display_name.
    
    FIX 3: добавлен ORDER BY для релевантности:
      0 — точное совпадение username
      1 — username начинается с запроса (prefix)
      2 — username содержит запрос (contains)
      3 — совпадение в display_name / first_name
    Без ORDER BY PostgreSQL возвращал строки в heap-order.
    """
    q_lower = q.lower().strip()

    relevance = case(
        (func.lower(User.username) == q_lower, 0),
        (func.lower(User.username).like(f"{q_lower}%"), 1),
        (func.lower(User.username).contains(q_lower), 2),
        else_=3,
    )

    stmt = (
        select(User)
        .where(
            User.id != current_user_id,
            User.is_active == True,  # noqa: E712
            User.is_public == True,   # noqa: E712
            User.id.notin_(blocked_ids) if blocked_ids else true(),
            or_(
                User.username.ilike(f"%{q}%"),
                User.first_name.ilike(f"%{q}%"),
                User.display_name.ilike(f"%{q}%"),
            ),
        )
        .order_by(relevance, User.username)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [
        {
            "id": user.id,
            "username": user.username,
            "first_name": user.first_name,
            "display_name": user.display_name,
            "avatar_url": user.avatar_url,
            "city": user.city,
        }
        for user in rows
    ]


async def search_playlists_db(
    q: str,
    db: AsyncSession,
    limit: int = 10,
) -> list[dict]:
    """Search public playlists by title.
    
    FIX 4: добавлен ORDER BY для релевантности:
      0 — точное совпадение title
      1 — title начинается с запроса
      2 — title содержит запрос (contains)
    """
    q_lower = q.lower().strip()

    relevance = case(
        (func.lower(Playlist.title) == q_lower, 0),
        (func.lower(Playlist.title).like(f"{q_lower}%"), 1),
        else_=2,
    )

    stmt = (
        select(Playlist)
        .where(
            Playlist.visibility == PlaylistVisibility.public,
            Playlist.title.ilike(f"%{q}%"),
        )
        .order_by(relevance, Playlist.title)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [
        {
            "id": pl.id,
            "title": pl.title,
            "description": pl.description,
            "cover_url": pl.cover_url,
        }
        for pl in rows
    ]


# ---------------------------------------------------------------------------
# Trending
# ---------------------------------------------------------------------------

async def track_search_query(q: str, redis) -> None:
    """Increment score for query in daily trending sorted set."""
    try:
        term = q.lower().strip()
        if term:
            await redis.zincrby(TRENDING_KEY, 1, term)
            await redis.expire(TRENDING_KEY, TRENDING_TTL)
    except Exception as exc:
        logger.debug("track_search_query failed: %s", exc)


async def get_trending_searches(redis, limit: int = 10) -> list[str]:
    """Return top trending search terms (list of strings)."""
    try:
        results = await redis.zrevrange(TRENDING_KEY, 0, limit - 1)
        return [r if isinstance(r, str) else r.decode("utf-8") for r in results]
    except Exception as exc:
        logger.debug("get_trending_searches failed: %s", exc)
        return []