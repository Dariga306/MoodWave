"""
search_service.py — Search logic: iTunes API, user/playlist DB queries, Redis trending.
"""
from __future__ import annotations

import json
import logging
from typing import Optional

import httpx
from sqlalchemy import or_, select, true
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.music import Playlist, PlaylistVisibility
from app.models.user import User

logger = logging.getLogger(__name__)

ITUNES_BASE_URL = "https://itunes.apple.com/search"
TRACK_CACHE_TTL = 300   # 5 minutes
TRENDING_TTL = 86400    # 24 hours
TRENDING_KEY = "search:trending:daily"


# ---------------------------------------------------------------------------
# iTunes track search with Redis cache
# ---------------------------------------------------------------------------

async def search_tracks_itunes(q: str, limit: int = 20, redis=None) -> list[dict]:
    """Search iTunes API with Redis cache (key: search:tracks:{q}).
    Returns [] on any error — never raises."""
    key = f"search:tracks:{q.lower().strip()}"

    if redis:
        try:
            cached = await redis.get(key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                ITUNES_BASE_URL,
                params={
                    "term": q,
                    "media": "music",
                    "entity": "song",
                    "limit": min(limit, 50),
                    "country": "US",
                },
            )
            resp.raise_for_status()
            data = resp.json()

        tracks = [
            {
                "track_id": str(item["trackId"]),
                "title": item.get("trackName", ""),
                "artist": item.get("artistName", ""),
                "album": item.get("collectionName", ""),
                "cover_url": item.get("artworkUrl100", "").replace("100x100", "300x300"),
                "preview_url": item.get("previewUrl", ""),
                "duration_ms": item.get("trackTimeMillis", 0),
                "genre": item.get("primaryGenreName", ""),
            }
            for item in data.get("results", [])
            if item.get("trackId")
        ]

        if redis and tracks:
            try:
                await redis.setex(key, TRACK_CACHE_TTL, json.dumps(tracks))
            except Exception:
                pass

        return tracks

    except Exception as exc:
        logger.warning("iTunes search failed for '%s': %s", q, exc)
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
    Excludes the current user and blocked users."""
    stmt = (
        select(User)
        .where(
            User.id != current_user_id,
            User.is_active == True,
            User.is_public == True,
            User.id.notin_(blocked_ids) if blocked_ids else true(),
            or_(
                User.username.ilike(f"%{q}%"),
                User.first_name.ilike(f"%{q}%"),
                User.display_name.ilike(f"%{q}%"),
            ),
        )
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
    """Search public playlists by title."""
    stmt = (
        select(Playlist)
        .where(
            Playlist.visibility == PlaylistVisibility.public,
            Playlist.title.ilike(f"%{q}%"),
        )
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
