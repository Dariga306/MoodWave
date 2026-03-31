"""Admin router — all endpoints require is_admin=True JWT bearer token."""
from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import delete, func, select, text, and_, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import AsyncSessionLocal
from app.dependencies import get_db, bearer_scheme
from app.models.chat import Chat
from app.models.music import ListeningHistory, Playlist, PlaylistTrack, TrackCache
from app.models.social import Match, Report
from app.models.rooms import ListeningRoom, RoomParticipant
from app.models.user import TasteVector, User, UserGenre, UserMood
from app.services.auth import verify_access_token

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Dependency
# ---------------------------------------------------------------------------

async def require_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    if credentials is None or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    payload = verify_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = await db.get(User, int(payload["sub"]))
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    if not getattr(user, "is_admin", False):
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _fmt_dt(dt: Optional[datetime]) -> Optional[str]:
    return dt.isoformat() if dt else None


# ---------------------------------------------------------------------------
# GET /admin/stats
# ---------------------------------------------------------------------------

@router.get("/stats")
async def admin_stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    total_users = (await db.execute(select(func.count()).select_from(User))).scalar_one()
    total_tracks = (await db.execute(select(func.count()).select_from(TrackCache))).scalar_one()
    total_playlists = (await db.execute(select(func.count()).select_from(Playlist))).scalar_one()
    total_matches = (await db.execute(select(func.count()).select_from(Match))).scalar_one()
    total_chats = (await db.execute(select(func.count()).select_from(Chat))).scalar_one()

    since = datetime.utcnow() - timedelta(days=30)
    reg_rows = (
        await db.execute(
            text("SELECT DATE(created_at) AS day, COUNT(*) AS cnt FROM users WHERE created_at >= :since GROUP BY day ORDER BY day"),
            {"since": since},
        )
    ).fetchall()
    registrations_per_day = [{"date": str(r.day), "count": int(r.cnt)} for r in reg_rows]

    top_tracks_rows = (
        await db.execute(
            text(
                "SELECT tc.spotify_id, tc.title, tc.artist, COUNT(lh.id) AS play_count "
                "FROM tracks_cache tc LEFT JOIN listening_history lh ON tc.spotify_id = lh.spotify_track_id "
                "GROUP BY tc.spotify_id, tc.title, tc.artist ORDER BY play_count DESC LIMIT 10"
            )
        )
    ).fetchall()
    top_tracks = [{"spotify_id": r.spotify_id, "title": r.title, "artist": r.artist, "play_count": int(r.play_count)} for r in top_tracks_rows]

    mood_rows = (
        await db.execute(
            text("SELECT mood, SUM(weight) AS total_weight FROM user_moods GROUP BY mood ORDER BY total_weight DESC LIMIT 10")
        )
    ).fetchall()
    mood_distribution = [{"mood": r.mood, "value": float(r.total_weight)} for r in mood_rows]

    event_rows = (
        await db.execute(
            text(
                "SELECT lh.id, lh.user_id, u.username, lh.spotify_track_id, "
                "COALESCE(tc.title, lh.spotify_track_id) AS track_title, "
                "COALESCE(tc.artist, '') AS track_artist, lh.action, lh.created_at "
                "FROM listening_history lh JOIN users u ON lh.user_id = u.id "
                "LEFT JOIN tracks_cache tc ON lh.spotify_track_id = tc.spotify_id "
                "ORDER BY lh.created_at DESC LIMIT 10"
            )
        )
    ).fetchall()
    recent_events = [
        {"id": r.id, "user_id": r.user_id, "username": r.username, "spotify_track_id": r.spotify_track_id,
         "track_title": r.track_title, "track_artist": r.track_artist, "action": r.action, "created_at": _fmt_dt(r.created_at)}
        for r in event_rows
    ]

    return {
        "totals": {"users": total_users, "tracks": total_tracks, "playlists": total_playlists, "matches": total_matches, "chats": total_chats},
        "registrations_per_day": registrations_per_day,
        "top_tracks": top_tracks,
        "mood_distribution": mood_distribution,
        "recent_events": recent_events,
    }


# ---------------------------------------------------------------------------
# GET /admin/users
# ---------------------------------------------------------------------------

@router.get("/users")
async def admin_list_users(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    is_admin: Optional[bool] = Query(None),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    q = select(User)
    conditions = []
    if search:
        like = f"%{search}%"
        conditions.append(or_(User.username.ilike(like), User.email.ilike(like)))
    if is_active is not None:
        conditions.append(User.is_active == is_active)
    if is_admin is not None:
        conditions.append(User.is_admin == is_admin)
    if conditions:
        q = q.where(and_(*conditions))

    total = (await db.execute(select(func.count()).select_from(q.subquery()))).scalar_one()
    users = (await db.execute(q.order_by(desc(User.created_at)).offset((page - 1) * limit).limit(limit))).scalars().all()

    return {
        "total": total, "page": page, "limit": limit,
        "items": [
            {"id": u.id, "username": u.username, "email": u.email, "display_name": u.display_name,
             "city": u.city, "is_active": u.is_active, "is_admin": u.is_admin, "is_verified": u.is_verified,
             "created_at": _fmt_dt(u.created_at)}
            for u in users
        ],
    }


# ---------------------------------------------------------------------------
# GET /admin/users/{user_id}
# ---------------------------------------------------------------------------

@router.get("/users/{user_id}")
async def admin_get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == user_id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == user_id))).scalars().all()
    taste = (await db.execute(select(TasteVector).where(TasteVector.user_id == user_id))).scalar_one_or_none()

    return {
        "id": user.id, "email": user.email, "username": user.username,
        "first_name": user.first_name, "last_name": user.last_name, "display_name": user.display_name,
        "avatar_url": user.avatar_url, "bio": user.bio,
        "birth_date": str(user.birth_date) if user.birth_date else None,
        "city": user.city, "gender": user.gender,
        "is_public": user.is_public, "show_activity": user.show_activity,
        "is_active": user.is_active, "is_verified": user.is_verified, "is_admin": user.is_admin,
        "created_at": _fmt_dt(user.created_at),
        "genres": [{"genre": g.genre, "weight": g.weight} for g in genres],
        "moods": [{"mood": m.mood, "weight": m.weight} for m in moods],
        "taste_vector": taste.vector if taste else None,
    }


# ---------------------------------------------------------------------------
# GET /admin/users/{user_id}/history
# ---------------------------------------------------------------------------

@router.get("/users/{user_id}/history")
async def admin_user_history(
    user_id: int,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    rows = (
        await db.execute(
            text(
                "SELECT lh.id, lh.spotify_track_id, COALESCE(tc.title, lh.spotify_track_id) AS track_title, "
                "COALESCE(tc.artist, '') AS track_artist, lh.action, lh.weight, lh.completion_pct, lh.mood, lh.created_at "
                "FROM listening_history lh LEFT JOIN tracks_cache tc ON lh.spotify_track_id = tc.spotify_id "
                "WHERE lh.user_id = :uid ORDER BY lh.created_at DESC LIMIT :lim"
            ),
            {"uid": user_id, "lim": limit},
        )
    ).fetchall()

    return [
        {"id": r.id, "spotify_track_id": r.spotify_track_id, "track_title": r.track_title,
         "track_artist": r.track_artist, "action": r.action, "weight": r.weight,
         "completion_pct": r.completion_pct, "mood": r.mood, "created_at": _fmt_dt(r.created_at)}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# PUT /admin/users/{user_id}/block
# ---------------------------------------------------------------------------

@router.put("/users/{user_id}/block")
async def admin_toggle_block(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
    user.is_active = not user.is_active
    await db.commit()
    return {"id": user.id, "is_active": user.is_active}


# ---------------------------------------------------------------------------
# PUT /admin/users/{user_id}/admin
# ---------------------------------------------------------------------------

@router.put("/users/{user_id}/admin")
async def admin_toggle_admin(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot modify your own admin status")
    user.is_admin = not user.is_admin
    await db.commit()
    return {"id": user.id, "is_admin": user.is_admin}


# ---------------------------------------------------------------------------
# DELETE /admin/users/{user_id}
# ---------------------------------------------------------------------------

@router.delete("/users/{user_id}")
async def admin_delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    await db.delete(user)
    await db.commit()
    return {"detail": "User deleted"}


# ---------------------------------------------------------------------------
# GET /admin/tracks
# ---------------------------------------------------------------------------

@router.get("/tracks")
async def admin_list_tracks(
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    where_clause = ""
    params: dict = {}
    if search:
        where_clause = "WHERE tc.title ILIKE :search OR tc.artist ILIKE :search"
        params["search"] = f"%{search}%"

    rows = (
        await db.execute(
            text(
                f"SELECT tc.spotify_id, tc.title, tc.artist, tc.album, tc.duration_ms, tc.cached_at, COUNT(lh.id) AS play_count "
                f"FROM tracks_cache tc LEFT JOIN listening_history lh ON tc.spotify_id = lh.spotify_track_id "
                f"{where_clause} GROUP BY tc.spotify_id, tc.title, tc.artist, tc.album, tc.duration_ms, tc.cached_at "
                f"ORDER BY play_count DESC"
            ),
            params,
        )
    ).fetchall()

    return [
        {"spotify_id": r.spotify_id, "title": r.title, "artist": r.artist, "album": r.album,
         "duration_ms": r.duration_ms, "cached_at": _fmt_dt(r.cached_at), "play_count": int(r.play_count)}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# DELETE /admin/tracks/{spotify_id}
# ---------------------------------------------------------------------------

@router.delete("/tracks/{spotify_id}")
async def admin_delete_track(
    spotify_id: str,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    track = (await db.execute(select(TrackCache).where(TrackCache.spotify_id == spotify_id))).scalar_one_or_none()
    if not track:
        raise HTTPException(status_code=404, detail="Track not found")
    await db.delete(track)
    await db.commit()
    return {"detail": "Track removed from cache"}


# ---------------------------------------------------------------------------
# GET /admin/playlists
# ---------------------------------------------------------------------------

@router.get("/playlists")
async def admin_list_playlists(
    visibility: Optional[str] = Query(None),
    is_collaborative: Optional[bool] = Query(None),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    conditions: list[str] = []
    params: dict = {}
    if visibility:
        conditions.append("p.visibility = :visibility")
        params["visibility"] = visibility
    if is_collaborative is not None:
        conditions.append("p.is_collaborative = :is_collab")
        params["is_collab"] = is_collaborative

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    rows = (
        await db.execute(
            text(
                f"SELECT p.id, p.title, u.username AS owner_username, p.visibility, p.is_collaborative, "
                f"COUNT(pt.id) AS track_count, p.created_at FROM playlists p "
                f"JOIN users u ON p.owner_id = u.id LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id "
                f"{where} GROUP BY p.id, p.title, u.username, p.visibility, p.is_collaborative, p.created_at "
                f"ORDER BY p.created_at DESC"
            ),
            params,
        )
    ).fetchall()

    return [
        {"id": r.id, "name": r.title, "owner_username": r.owner_username, "visibility": r.visibility,
         "collaborative": r.is_collaborative, "track_count": int(r.track_count), "created_at": _fmt_dt(r.created_at)}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# GET /admin/playlists/{playlist_id}/tracks
# ---------------------------------------------------------------------------

@router.get("/playlists/{playlist_id}/tracks")
async def admin_playlist_tracks(
    playlist_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")

    rows = (
        await db.execute(
            text(
                "SELECT pt.position, pt.spotify_track_id, COALESCE(tc.title, pt.spotify_track_id) AS title, "
                "COALESCE(tc.artist, '') AS artist, tc.album, tc.duration_ms, pt.added_at "
                "FROM playlist_tracks pt LEFT JOIN tracks_cache tc ON pt.spotify_track_id = tc.spotify_id "
                "WHERE pt.playlist_id = :pid ORDER BY pt.position"
            ),
            {"pid": playlist_id},
        )
    ).fetchall()

    return [
        {"position": r.position, "spotify_track_id": r.spotify_track_id, "title": r.title,
         "artist": r.artist, "album": r.album, "duration_ms": r.duration_ms, "added_at": _fmt_dt(r.added_at)}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# DELETE /admin/playlists/{playlist_id}
# ---------------------------------------------------------------------------

@router.delete("/playlists/{playlist_id}")
async def admin_delete_playlist(
    playlist_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    await db.delete(playlist)
    await db.commit()
    return {"detail": "Playlist deleted"}


# ---------------------------------------------------------------------------
# GET /admin/matches
# ---------------------------------------------------------------------------

@router.get("/matches")
async def admin_list_matches(
    sim_min: Optional[int] = Query(None, ge=0, le=100),
    sim_max: Optional[int] = Query(None, ge=0, le=100),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    conditions: list[str] = []
    params: dict = {}
    if sim_min is not None:
        conditions.append("m.similarity_pct >= :sim_min")
        params["sim_min"] = sim_min
    if sim_max is not None:
        conditions.append("m.similarity_pct <= :sim_max")
        params["sim_max"] = sim_max

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    rows = (
        await db.execute(
            text(
                f"SELECT m.id, ua.username AS user_a, ub.username AS user_b, m.similarity_pct, m.created_at "
                f"FROM matches m JOIN users ua ON m.user_a_id = ua.id JOIN users ub ON m.user_b_id = ub.id "
                f"{where} ORDER BY m.created_at DESC"
            ),
            params,
        )
    ).fetchall()

    return [
        {"id": r.id, "user_a": r.user_a, "user_b": r.user_b,
         "similarity_pct": r.similarity_pct, "created_at": _fmt_dt(r.created_at)}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# DELETE /admin/matches/{match_id}
# ---------------------------------------------------------------------------

@router.delete("/matches/{match_id}")
async def admin_delete_match(
    match_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    match = await db.get(Match, match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    await db.delete(match)
    await db.commit()
    return {"detail": "Match deleted"}


# ---------------------------------------------------------------------------
# GET /admin/analytics
# ---------------------------------------------------------------------------

@router.get("/analytics")
async def admin_analytics(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    since = datetime.utcnow() - timedelta(days=30)

    dau_rows = (
        await db.execute(
            text("SELECT DATE(created_at) AS day, COUNT(DISTINCT user_id) AS active_users FROM listening_history WHERE created_at >= :since GROUP BY day ORDER BY day"),
            {"since": since},
        )
    ).fetchall()
    dau = [{"date": str(r.day), "active_users": int(r.active_users)} for r in dau_rows]

    genre_rows = (
        await db.execute(text("SELECT genre, SUM(weight) AS total_weight FROM user_genres GROUP BY genre ORDER BY total_weight DESC LIMIT 10"))
    ).fetchall()
    top_genres = [{"genre": r.genre, "weight": float(r.total_weight)} for r in genre_rows]

    city_rows = (
        await db.execute(text("SELECT city, COUNT(*) AS user_count FROM users WHERE city IS NOT NULL AND city != '' GROUP BY city ORDER BY user_count DESC LIMIT 5"))
    ).fetchall()
    top_cities = [{"city": r.city, "count": int(r.user_count)} for r in city_rows]

    avg_sim = (await db.execute(text("SELECT COALESCE(AVG(similarity_pct), 0) FROM matches"))).scalar_one()
    avg_tracks = (
        await db.execute(text("SELECT COALESCE(AVG(cnt), 0) FROM (SELECT COUNT(*) AS cnt FROM listening_history GROUP BY user_id) AS sub"))
    ).scalar_one()

    return {
        "daily_active_users": dau,
        "top_genres": top_genres,
        "top_cities": top_cities,
        "avg_similarity_pct": round(float(avg_sim), 2),
        "avg_tracks_per_user": round(float(avg_tracks), 2),
    }


# ---------------------------------------------------------------------------
# GET /admin/system
# ---------------------------------------------------------------------------

@router.get("/system")
async def admin_system(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    redis = request.app.state.redis

    track_keys: list[str] = []
    async for k in redis.scan_iter(match="search:tracks:*"):
        track_keys.append(k)
    redis_track_count = len(track_keys)

    table_names = [
        "users", "user_genres", "user_moods", "taste_vectors",
        "tracks_cache", "listening_history", "playlists", "playlist_tracks",
        "matches", "match_decisions", "friends", "blocks", "reports",
        "chats", "listening_rooms", "room_participants",
    ]
    table_counts: dict[str, int] = {}
    for tbl in table_names:
        try:
            cnt = (await db.execute(text(f"SELECT COUNT(*) FROM {tbl}"))).scalar_one()
            table_counts[tbl] = int(cnt)
        except Exception:
            table_counts[tbl] = -1

    rows = (
        await db.execute(
            text(
                "SELECT lh.id, lh.user_id, u.username, lh.spotify_track_id, "
                "COALESCE(tc.title, lh.spotify_track_id) AS track_title, lh.action, lh.created_at "
                "FROM listening_history lh JOIN users u ON lh.user_id = u.id "
                "LEFT JOIN tracks_cache tc ON lh.spotify_track_id = tc.spotify_id "
                "ORDER BY lh.created_at DESC LIMIT 20"
            )
        )
    ).fetchall()

    recent_events = [
        {"id": r.id, "user_id": r.user_id, "username": r.username,
         "spotify_track_id": r.spotify_track_id, "track_title": r.track_title,
         "action": r.action, "created_at": _fmt_dt(r.created_at)}
        for r in rows
    ]

    return {
        "redis_track_cache_count": redis_track_count,
        "table_counts": table_counts,
        "recent_events": recent_events,
    }


# ---------------------------------------------------------------------------
# POST /admin/system/clear-cache
# ---------------------------------------------------------------------------

@router.post("/system/clear-cache")
async def admin_clear_cache(
    request: Request,
    _admin: User = Depends(require_admin),
):
    redis = request.app.state.redis
    patterns = ["search:tracks:*", "recommendations:*", "now_playing:*", "match_candidates:*", "taste_vector:*", "room:*"]
    deleted = 0
    for pattern in patterns:
        async for key in redis.scan_iter(match=pattern):
            await redis.delete(key)
            deleted += 1
    return {"detail": f"Cleared {deleted} Redis keys"}


# ---------------------------------------------------------------------------
# GET /admin/reports
# ---------------------------------------------------------------------------

@router.get("/reports")
async def admin_list_reports(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    rows = (
        await db.execute(
            text(
                "SELECT r.id, r.reason, r.details, r.created_at, "
                "u1.username AS reporter_username, u1.id AS reporter_id, "
                "u2.username AS reported_username, u2.id AS reported_id "
                "FROM reports r "
                "JOIN users u1 ON r.reporter_id = u1.id "
                "JOIN users u2 ON r.reported_id = u2.id "
                "ORDER BY r.created_at DESC"
            )
        )
    ).fetchall()
    return [
        {"id": r.id, "reason": r.reason, "details": r.details,
         "reporter_id": r.reporter_id, "reporter_username": r.reporter_username,
         "reported_id": r.reported_id, "reported_username": r.reported_username,
         "created_at": _fmt_dt(r.created_at)}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# DELETE /admin/reports/{report_id}
# ---------------------------------------------------------------------------

@router.delete("/reports/{report_id}")
async def admin_dismiss_report(
    report_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    report = await db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    await db.delete(report)
    await db.commit()
    return {"detail": "Report dismissed"}


# ---------------------------------------------------------------------------
# GET /admin/rooms
# ---------------------------------------------------------------------------

@router.get("/rooms")
async def admin_list_rooms(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    rows = (
        await db.execute(
            text(
                "SELECT lr.id, lr.title AS name, lr.is_active, lr.is_public, lr.max_guests, "
                "lr.current_track_spotify_id, lr.created_at, lr.closed_at, "
                "u.username AS host_username, u.id AS host_id, "
                "COALESCE(tc.title, lr.current_track_spotify_id) AS track_title, "
                "COALESCE(tc.artist, '') AS track_artist, "
                "COUNT(rp.id) FILTER (WHERE rp.status = 'connected') AS participant_count "
                "FROM listening_rooms lr "
                "JOIN users u ON lr.host_id = u.id "
                "LEFT JOIN tracks_cache tc ON lr.current_track_spotify_id = tc.spotify_id "
                "LEFT JOIN room_participants rp ON lr.id = rp.room_id "
                "GROUP BY lr.id, lr.title, u.username, u.id, tc.title, tc.artist "
                "ORDER BY lr.is_active DESC, lr.created_at DESC LIMIT 50"
            )
        )
    ).fetchall()
    return [
        {"id": r.id, "name": r.name, "is_active": r.is_active, "is_public": r.is_public,
         "max_guests": r.max_guests, "host_id": r.host_id, "host_username": r.host_username,
         "current_track_spotify_id": r.current_track_spotify_id,
         "track_title": r.track_title, "track_artist": r.track_artist,
         "participant_count": int(r.participant_count or 0),
         "created_at": _fmt_dt(r.created_at), "closed_at": _fmt_dt(r.closed_at)}
        for r in rows
    ]


# ---------------------------------------------------------------------------
# DELETE /admin/rooms/{room_id}
# ---------------------------------------------------------------------------

@router.delete("/rooms/{room_id}")
async def admin_close_room(
    room_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    room = await db.get(ListeningRoom, room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    room.is_active = False
    room.closed_at = datetime.utcnow()
    await db.commit()
    return {"detail": "Room closed"}
