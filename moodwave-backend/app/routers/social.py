from __future__ import annotations

import json
from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import and_, delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

import asyncio

from app.dependencies import get_current_user, get_db
from app.models.music import ListeningHistory, TrackCache
from app.models.social import ArtistFollow, Block, Friend, FriendStatus, Match, Report, UserFollow
from app.models.user import User
from app.services import cache as cache_svc
from app.services import deezer as deezer_service
from app.services import firebase as firebase_svc
from app.services.security import users_are_blocked

router = APIRouter()


def _time_ago(dt: datetime) -> str:
    delta = datetime.utcnow() - dt
    mins = int(delta.total_seconds() / 60)
    if mins < 1:
        return "Just now"
    if mins < 60:
        return f"{mins} min ago"
    hours = mins // 60
    if hours < 24:
        return f"{hours}h ago"
    days = hours // 24
    if days == 1:
        return "Yesterday"
    return f"{days} days ago"


class ReportRequest(BaseModel):
    reason: Literal["spam", "inappropriate", "harassment"]
    details: str = ""


def _friend_payload(user: User) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "first_name": user.first_name,
        "avatar_url": user.avatar_url,
        "city": user.city,
    }


def _notification_name(user: User) -> str:
    return user.first_name or user.display_name or user.username


def _normalize_now_playing(raw_value: str | None) -> dict | None:
    if not raw_value:
        return None
    try:
        payload = json.loads(raw_value)
    except (TypeError, json.JSONDecodeError):
        return None

    return {
        "track_id": payload.get("track_id") or payload.get("spotify_id"),
        "title": payload.get("title"),
        "artist": payload.get("artist"),
        "played_at": payload.get("played_at"),
    }


async def _friend_rows(db: AsyncSession, current_user_id: int):
    return (
        await db.execute(
            select(Friend, User)
            .where(
                or_(Friend.requester_id == current_user_id, Friend.addressee_id == current_user_id),
                Friend.status == FriendStatus.accepted,
            )
            .join(
                User,
                or_(
                    and_(Friend.requester_id == current_user_id, User.id == Friend.addressee_id),
                    and_(Friend.addressee_id == current_user_id, User.id == Friend.requester_id),
                ),
            )
            .order_by(Friend.created_at.desc())
        )
    ).all()


async def _following_rows(db: AsyncSession, current_user_id: int):
    return (
        await db.execute(
            select(User)
            .join(UserFollow, UserFollow.following_id == User.id)
            .where(UserFollow.follower_id == current_user_id)
            .order_by(UserFollow.created_at.desc())
        )
    ).scalars().all()


async def _latest_play_snapshot(db: AsyncSession, user_id: int) -> dict | None:
    row = (
        await db.execute(
            select(ListeningHistory, TrackCache)
            .join(
                TrackCache,
                TrackCache.spotify_id == ListeningHistory.spotify_track_id,
                isouter=True,
            )
            .where(ListeningHistory.user_id == user_id)
            .order_by(ListeningHistory.created_at.desc())
            .limit(1)
        )
    ).first()
    if not row:
        return None

    history, track = row
    title = track.title if track else ""
    artist = track.artist if track else ""
    if not title and not artist:
        return None

    return {
        "track_id": history.spotify_track_id,
        "title": title,
        "artist": artist,
        "played_at": history.created_at.isoformat() + "Z"
        if history.created_at
        else None,
    }


async def _friendship_between_users(db: AsyncSession, user_a_id: int, user_b_id: int) -> Friend | None:
    return await db.scalar(
        select(Friend).where(
            or_(
                and_(Friend.requester_id == user_a_id, Friend.addressee_id == user_b_id),
                and_(Friend.requester_id == user_b_id, Friend.addressee_id == user_a_id),
            )
        )
    )


@router.get(
    "/friends",
    summary="List friends",
    description="Returns accepted friends for the current user, excluding anyone involved in a block relationship.",
)
async def list_friends(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = await _friend_rows(db, current_user.id)
    friends: list[dict] = []
    for _friendship, user in rows:
        if await users_are_blocked(db, current_user.id, user.id):
            continue
        friends.append(_friend_payload(user))
    return {"friends": friends}


@router.get(
    "/friends/activity",
    summary="Get friends activity",
    description="Returns accepted friends split into 'live' (listening within 2 min) and 'recent' (within 10 min), based on Redis now-playing data.",
)
async def friends_activity(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    rows = await _friend_rows(db, current_user.id)
    following_rows = await _following_rows(db, current_user.id)
    live: list[dict] = []
    recent: list[dict] = []
    seen_ids: set[int] = set()

    now_utc = datetime.utcnow()

    async def append_activity_user(user: User):
        if await users_are_blocked(db, current_user.id, user.id):
            return

        now_playing = None
        if user.show_activity:
            try:
                now_playing = _normalize_now_playing(
                    await redis.get(f"now_playing:{user.id}")
                )
            except Exception:
                now_playing = None
            now_playing = now_playing or await _latest_play_snapshot(db, user.id)

        friend_data = {**_friend_payload(user), "now_playing": now_playing}
        seen_ids.add(user.id)

        if now_playing and now_playing.get("played_at"):
            try:
                played_dt = datetime.fromisoformat(
                    now_playing["played_at"].replace("Z", "+00:00")
                ).replace(tzinfo=None)
                age_secs = (now_utc - played_dt).total_seconds()
                if age_secs <= 120:  # 2 minutes → live
                    live.append(friend_data)
                elif age_secs <= 600:  # 10 minutes → recent
                    recent.append(friend_data)
                else:
                    recent.append(friend_data)  # older but still show
            except (ValueError, TypeError):
                recent.append(friend_data)
        else:
            recent.append(friend_data)

    for _friendship, user in rows:
        await append_activity_user(user)

    for user in following_rows:
        if user.id in seen_ids:
            continue
        await append_activity_user(user)

    # Also include matched users (mutual likes) so activity is populated
    # even without explicit friends/follows
    match_rows = (
        await db.execute(
            select(User)
            .join(
                Match,
                or_(
                    and_(Match.user_a_id == current_user.id, User.id == Match.user_b_id),
                    and_(Match.user_b_id == current_user.id, User.id == Match.user_a_id),
                ),
            )
            .order_by(Match.created_at.desc())
        )
    ).scalars().all()

    for user in match_rows:
        if user.id in seen_ids:
            continue
        await append_activity_user(user)

    return {"live": live, "recent": recent}


@router.post(
    "/friends/{user_id}/request",
    summary="Send friend request",
    description="Creates a pending friend request and sends a push notification to the requested user.",
)
async def send_friend_request(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")

    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    if await users_are_blocked(db, current_user.id, user_id):
        raise HTTPException(status_code=403, detail="User is blocked")

    existing = await _friendship_between_users(db, current_user.id, user_id)
    if existing:
        if existing.status == FriendStatus.accepted:
            raise HTTPException(status_code=400, detail="Already friends")
        raise HTTPException(status_code=400, detail="Request already sent")

    db.add(
        Friend(
            requester_id=current_user.id,
            addressee_id=user_id,
            status=FriendStatus.pending,
        )
    )
    await db.commit()

    await firebase_svc.send_push_notification(
        token=target.fcm_token,
        title="Friend request",
        body=f"👋 {_notification_name(current_user)} wants to be your friend on MoodWave",
        data={"event": "friend_request", "user_id": current_user.id},
    )
    return {"message": "Request sent", "status": "pending"}


@router.post(
    "/friends/{user_id}/accept",
    summary="Accept friend request",
    description="Accepts a pending friend request as the recipient and notifies the original requester.",
)
async def accept_friend_request(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    relation = await db.scalar(
        select(Friend).where(
            Friend.requester_id == user_id,
            Friend.addressee_id == current_user.id,
            Friend.status == FriendStatus.pending,
        )
    )
    if not relation:
        own_request = await db.scalar(
            select(Friend).where(
                Friend.requester_id == current_user.id,
                Friend.addressee_id == user_id,
                Friend.status == FriendStatus.pending,
            )
        )
        if own_request:
            raise HTTPException(status_code=403, detail="Only the recipient can accept this request")
        raise HTTPException(status_code=404, detail="Friend request not found")

    relation.status = FriendStatus.accepted
    await db.commit()

    requester = await db.get(User, user_id)
    await firebase_svc.send_push_notification(
        token=requester.fcm_token if requester else None,
        title="Friend request accepted",
        body=f"🎉 {_notification_name(current_user)} accepted your friend request!",
        data={"event": "friend_accepted", "user_id": current_user.id},
    )
    return {"message": "Friend added", "status": "accepted"}


@router.delete(
    "/friends/{user_id}",
    summary="Remove friend",
    description="Removes the friendship relationship between the current user and the specified user.",
)
async def remove_friend(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await db.execute(
        delete(Friend).where(
            or_(
                and_(Friend.requester_id == current_user.id, Friend.addressee_id == user_id),
                and_(Friend.requester_id == user_id, Friend.addressee_id == current_user.id),
            )
        )
    )
    await db.commit()
    return {"message": "Friend removed"}


@router.post(
    "/users/{user_id}/block",
    summary="Block user",
    description="Blocks a user, removes any friendship, and invalidates search and match caches for both sides.",
)
async def block_user(
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")

    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    exists = await db.scalar(
        select(Block).where(Block.blocker_id == current_user.id, Block.blocked_id == user_id)
    )
    if exists:
        raise HTTPException(status_code=400, detail="Already blocked")

    db.add(Block(blocker_id=current_user.id, blocked_id=user_id))
    await db.execute(
        delete(Friend).where(
            or_(
                and_(Friend.requester_id == current_user.id, Friend.addressee_id == user_id),
                and_(Friend.requester_id == user_id, Friend.addressee_id == current_user.id),
            )
        )
    )
    await db.commit()

    await cache_svc.invalidate_match_candidates(request.app.state.redis, [current_user.id, user_id])
    await cache_svc.invalidate_search_results_for_users(request.app.state.redis, [current_user.id, user_id])
    return {"message": "User blocked"}


@router.delete(
    "/users/{user_id}/block",
    summary="Unblock user",
    description="Removes an existing block relationship and refreshes caches for both sides.",
)
async def unblock_user(
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot unblock yourself")

    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    block = await db.scalar(
        select(Block).where(
            Block.blocker_id == current_user.id,
            Block.blocked_id == user_id,
        )
    )
    if not block:
        raise HTTPException(status_code=404, detail="Block not found")

    await db.delete(block)
    await db.commit()

    await cache_svc.invalidate_match_candidates(
        request.app.state.redis, [current_user.id, user_id]
    )
    await cache_svc.invalidate_search_results_for_users(
        request.app.state.redis, [current_user.id, user_id]
    )
    return {"message": "User unblocked"}


@router.post(
    "/users/{user_id}/report",
    summary="Report user",
    description="Submits a moderation report for another user with a structured reason and optional details.",
)
async def report_user(
    user_id: int,
    body: ReportRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    db.add(
        Report(
            reporter_id=current_user.id,
            reported_id=user_id,
            reason=body.reason,
            details=body.details or "",
        )
    )
    await db.commit()
    return {"message": "Report submitted. We will review it."}


@router.get(
    "/notifications",
    summary="Get notifications",
    description="Returns aggregated notifications: mutual matches and pending friend requests, sorted newest first.",
)
async def get_notifications(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notifications: list[dict] = []

    # Recent mutual matches
    match_rows = (
        await db.execute(
            select(Match, User)
            .where(or_(Match.user_a_id == current_user.id, Match.user_b_id == current_user.id))
            .join(
                User,
                or_(
                    and_(Match.user_a_id == current_user.id, User.id == Match.user_b_id),
                    and_(Match.user_b_id == current_user.id, User.id == Match.user_a_id),
                ),
            )
            .order_by(Match.created_at.desc())
            .limit(20)
        )
    ).all()

    for match, other in match_rows:
        if await users_are_blocked(db, current_user.id, other.id):
            continue
        name = other.first_name or other.display_name or other.username
        notifications.append(
            {
                "id": f"match_{match.id}",
                "type": "match",
                "user_id": other.id,
                "user_name": name,
                "user_initial": name[0].upper() if name else "?",
                "avatar_url": other.avatar_url,
                "city": other.city,
                "similarity_pct": match.similarity_pct,
                "text": f"{match.similarity_pct}% match found — meet {name}",
                "time": _time_ago(match.created_at),
                "created_at": match.created_at.isoformat(),
            }
        )

    # Pending friend requests addressed to current user
    pending_rows = (
        await db.execute(
            select(Friend, User)
            .where(
                Friend.addressee_id == current_user.id,
                Friend.status == FriendStatus.pending,
            )
            .join(User, User.id == Friend.requester_id)
            .order_by(Friend.created_at.desc())
            .limit(20)
        )
    ).all()

    for friend_req, requester in pending_rows:
        if await users_are_blocked(db, current_user.id, requester.id):
            continue
        name = requester.first_name or requester.display_name or requester.username
        notifications.append(
            {
                "id": f"friend_req_{friend_req.id}",
                "type": "friend_request",
                "user_id": requester.id,
                "user_name": name,
                "user_initial": name[0].upper() if name else "?",
                "avatar_url": requester.avatar_url,
                "text": f"{name} sent you a friend request",
                "time": _time_ago(friend_req.created_at),
                "created_at": friend_req.created_at.isoformat(),
            }
        )

    notifications.sort(key=lambda n: n["created_at"], reverse=True)
    return {"notifications": notifications}


@router.post(
    "/users/{user_id:int}/follow",
    summary="Follow user",
    description="Follows a user (subscribe). Idempotent.",
)
async def follow_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    existing = await db.scalar(
        select(UserFollow).where(
            UserFollow.follower_id == current_user.id,
            UserFollow.following_id == user_id,
        )
    )
    if not existing:
        db.add(UserFollow(follower_id=current_user.id, following_id=user_id))
        await db.commit()
    return {"message": "Following"}


@router.delete(
    "/users/{user_id:int}/follow",
    summary="Unfollow user",
    description="Unfollows a user (unsubscribe).",
)
async def unfollow_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await db.execute(
        delete(UserFollow).where(
            UserFollow.follower_id == current_user.id,
            UserFollow.following_id == user_id,
        )
    )
    await db.commit()
    return {"message": "Unfollowed"}


@router.get(
    "/users/{user_id:int}/followers",
    summary="Get user followers",
    description="Returns paginated list of followers for a user.",
)
async def get_user_followers(
    user_id: int,
    offset: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = await db.get(User, user_id)
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
    if (
        current_user.id != user_id
        and not getattr(target_user, "show_followers", True)
    ):
        raise HTTPException(status_code=403, detail="Followers are hidden")

    rows = (
        await db.execute(
            select(User)
            .join(UserFollow, UserFollow.follower_id == User.id)
            .where(UserFollow.following_id == user_id)
            .offset(offset)
            .limit(limit)
        )
    ).scalars().all()
    return [_friend_payload(u) for u in rows]


@router.get(
    "/users/{user_id:int}/following",
    summary="Get user following",
    description="Returns paginated list of users that a user is following.",
)
async def get_user_following(
    user_id: int,
    offset: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = await db.get(User, user_id)
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
    if (
        current_user.id != user_id
        and not getattr(target_user, "show_followers", True)
    ):
        raise HTTPException(status_code=403, detail="Following is hidden")

    rows = (
        await db.execute(
            select(User)
            .join(UserFollow, UserFollow.following_id == User.id)
            .where(UserFollow.follower_id == user_id)
            .offset(offset)
            .limit(limit)
        )
    ).scalars().all()
    return [_friend_payload(u) for u in rows]


@router.post(
    "/users/me/following/{deezer_artist_id:int}",
    summary="Follow artist",
    description="Follows a Deezer artist for the current user.",
)
async def follow_artist(
    deezer_artist_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = await db.scalar(
        select(ArtistFollow).where(
            ArtistFollow.user_id == current_user.id,
            ArtistFollow.deezer_artist_id == deezer_artist_id,
        )
    )
    if not existing:
        db.add(ArtistFollow(user_id=current_user.id, deezer_artist_id=deezer_artist_id))
        await db.commit()
    return {"message": "Artist followed"}


@router.delete(
    "/users/me/following/{deezer_artist_id:int}",
    summary="Unfollow artist",
    description="Removes a followed Deezer artist for the current user.",
)
async def unfollow_artist(
    deezer_artist_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await db.execute(
        delete(ArtistFollow).where(
            ArtistFollow.user_id == current_user.id,
            ArtistFollow.deezer_artist_id == deezer_artist_id,
        )
    )
    await db.commit()
    return {"message": "Artist unfollowed"}


@router.get(
    "/users/me/following",
    summary="List followed artists",
    description="Returns followed Deezer artist ids for the current user.",
)
async def list_followed_artists(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(ArtistFollow.deezer_artist_id)
            .where(ArtistFollow.user_id == current_user.id)
            .order_by(ArtistFollow.created_at.desc())
        )
    ).scalars().all()
    return list(rows)


async def _followed_artist_profiles(db: AsyncSession, user_id: int) -> list[dict]:
    rows = (
        await db.execute(
            select(ArtistFollow.deezer_artist_id)
            .where(ArtistFollow.user_id == user_id)
            .order_by(ArtistFollow.created_at.desc())
        )
    ).scalars().all()

    if not rows:
        return []

    payload: list[dict] = []
    for artist_id in rows:
        try:
            artist = await deezer_service.get_artist(artist_id)
            if isinstance(artist, dict) and artist:
                payload.append(artist)
            else:
                payload.append({"id": artist_id, "name": f"Artist {artist_id}"})
        except Exception:
            payload.append({"id": artist_id, "name": f"Artist {artist_id}"})
    return payload


@router.get(
    "/users/me/following/details",
    summary="List followed artists with profiles",
    description="Returns full Deezer artist profiles for the current user's followed artists (limit 10).",
)
async def list_followed_artists_details(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await _followed_artist_profiles(db, current_user.id)


@router.get(
    "/users/{user_id:int}/following/artists",
    summary="Get followed artists for user",
    description="Returns Deezer artist profiles followed by the requested user.",
)
async def get_user_following_artists(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return await _followed_artist_profiles(db, user_id)


@router.get(
    "/users/{user_id:int}/now-playing",
    summary="Get user now-playing status",
)
async def get_user_now_playing(
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    now_playing = None
    if user.show_activity:
        try:
            redis = request.app.state.redis
            now_playing = _normalize_now_playing(await redis.get(f"now_playing:{user_id}"))
        except Exception:
            pass
        if not now_playing:
            now_playing = await _latest_play_snapshot(db, user_id)
    return {"now_playing": now_playing}
