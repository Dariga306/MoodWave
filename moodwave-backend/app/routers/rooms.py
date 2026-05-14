from __future__ import annotations

import base64
import json
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db, require_verified_user
from app.models.rooms import (
    ListeningRoom,
    RoomParticipant,
    RoomParticipantRole,
    RoomParticipantStatus,
)
from app.models.user import User
from app.services import firebase as firebase_svc
from app.services.auth import create_ws_token, verify_ws_token
from app.services.room_sync import adjust_position, manager

router = APIRouter()

ROOM_STATE_TTL = 3600
ROOM_SETTINGS_TTL = 86400  # 24 h — settings survive server restarts
QUEUE_TTL = 3600
REQUEST_TTL = 300
DEFAULT_ROOM_NAME = "Listening Party"
UPLOADS_DIR = Path(__file__).resolve().parents[2] / "uploads"
ROOM_UPLOADS_DIR = UPLOADS_DIR / "rooms"


class CreateRoomRequest(BaseModel):
    name: str | None = Field(default=None, max_length=255)
    description: str | None = Field(default=None, max_length=500)
    background_url: str | None = Field(default=None, max_length=2048)
    background_data_url: str | None = None
    is_public: bool = False
    max_guests: int = Field(default=10, ge=1)
    require_approval: bool | None = None
    allow_track_suggestions: bool = True
    allow_chat: bool = True
    quiet_mode: bool = False
    democratic_queue: bool = False


class JoinApprovalRequest(BaseModel):
    user_id: int


class JoinDeclineRequest(BaseModel):
    user_id: int


class RoomMessageRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


class RoomMessageUpdateRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


class RoomPinRequest(BaseModel):
    message_id: str = Field(..., min_length=1, max_length=128)
    preview: str | None = Field(default="", max_length=180)


class RoomPollRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=160)
    options: list[str] = Field(..., min_length=2, max_length=6)


class RoomPollVoteRequest(BaseModel):
    option_index: int = Field(..., ge=0)


class QueueTrackRequest(BaseModel):
    track_id: str
    title: str
    artist: str
    cover_url: str | None = None
    preview_url: str | None = None
    duration_ms: int | None = None


class PlaybackUpdateRequest(BaseModel):
    event: str = Field(default="heartbeat", max_length=32)
    track_id: str | None = None
    track_spotify_id: str | None = None
    track_title: str | None = None
    track_artist: str | None = None
    track_cover_url: str | None = None
    preview_url: str | None = None
    track_duration_ms: int | None = Field(default=None, ge=0)
    position_ms: int | None = Field(default=None, ge=0)
    is_playing: bool | None = None


class QueueBulkRequest(BaseModel):
    tracks: list[QueueTrackRequest] = Field(..., min_length=1, max_length=50)


class QueueReorderRequest(BaseModel):
    from_index: int = Field(..., ge=0)
    to_index: int = Field(..., ge=0)


class RoomRoleRequest(BaseModel):
    role: str = Field(..., pattern="^(co_host|listener|participant)$")


class RoomSettingsUpdateRequest(BaseModel):
    name: str | None = Field(default=None, max_length=255)
    description: str | None = Field(default=None, max_length=500)
    background_url: str | None = Field(default=None, max_length=2048)
    background_data_url: str | None = None
    is_public: bool | None = None
    locked: bool | None = None
    allow_track_suggestions: bool | None = None
    allow_chat: bool | None = None
    quiet_mode: bool | None = None
    democratic_queue: bool | None = None
    require_approval: bool | None = None
    max_participants: int | None = Field(default=None, ge=1, le=100)


def _invite_code(room_id: int) -> str:
    return f"MW-{room_id:04X}"


def _ws_url(request: Request, room_id: int, token: str) -> str:
    base = urlparse(str(request.base_url))
    scheme = "wss" if base.scheme == "https" else "ws"
    return f"{scheme}://{base.netloc}/ws/rooms/{room_id}?token={token}"


def _request_key(room_id: int, user_id: int) -> str:
    return f"room:{room_id}:request:{user_id}"


def _queue_key(room_id: int) -> str:
    return f"room:{room_id}:queue"


def _settings_key(room_id: int) -> str:
    return f"room:{room_id}:settings"


def _presence_key(room_id: int, user_id: int) -> str:
    return f"room:{room_id}:presence:{user_id}"


def _role_key(room_id: int, user_id: int) -> str:
    return f"room:{room_id}:role:{user_id}"


def _banned_key(room_id: int) -> str:
    return f"room:{room_id}:banned"


def _muted_key(room_id: int) -> str:
    return f"room:{room_id}:muted"


def _pinned_key(room_id: int) -> str:
    return f"room:{room_id}:pinned"


def _poll_key(room_id: int) -> str:
    return f"room:{room_id}:poll"


def _hidden_room_history_key(user_id: int) -> str:
    return f"hidden_room_history:{user_id}"


def _deleted_room_history_key() -> str:
    return "deleted_room_history"


_ROOM_PINS_FALLBACK: dict[int, list[dict[str, Any]]] = {}
_ROOM_POLL_FALLBACK: dict[int, dict[str, Any]] = {}


def _display_name(user: User) -> str:
    return user.first_name or user.display_name or user.username


def _save_room_background_data_url(request: Request, data_url: str | None) -> str:
    if not data_url:
        return ""
    match = re.match(r"^data:(image/(?:png|jpe?g|webp|gif));base64,(.+)$", data_url, re.I | re.S)
    if not match:
        raise HTTPException(status_code=400, detail="Invalid room background image")
    mime = match.group(1).lower()
    ext = {
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/webp": ".webp",
        "image/gif": ".gif",
    }.get(mime)
    if not ext:
        raise HTTPException(status_code=400, detail="Unsupported room background format")
    try:
        data = base64.b64decode(match.group(2), validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid room background image")
    if not data or len(data) > 6 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Room background must be <= 6 MB")
    ROOM_UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    file_name = f"room_bg_{int(time.time())}_{uuid4().hex[:10]}{ext}"
    (ROOM_UPLOADS_DIR / file_name).write_bytes(data)
    return str(request.url_for("uploads", path=f"rooms/{file_name}"))


async def _connected_guest_count(db: AsyncSession, room_id: int) -> int:
    return int(
        await db.scalar(
            select(func.count(RoomParticipant.id)).where(
                RoomParticipant.room_id == room_id,
                RoomParticipant.role == RoomParticipantRole.guest,
                RoomParticipant.status == RoomParticipantStatus.connected,
            )
        )
        or 0
    )


async def _connected_participant_count(db: AsyncSession, redis, room_id: int) -> int:
    rows = await db.scalars(
        select(RoomParticipant.user_id).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.status == RoomParticipantStatus.connected,
        )
    )
    count = 0
    for user_id in rows.all():
        try:
            if await redis.get(_presence_key(room_id, int(user_id))):
                count += 1
        except Exception:
            pass
    return count


async def _room_settings(redis, room: ListeningRoom) -> dict[str, Any]:
    raw = await redis.get(_settings_key(room.id))
    defaults = {
        "is_public": room.is_public,
        "locked": not room.is_public,
        "description": room.description or "",
        "background_url": getattr(room, "background_url", None) or "",
        "allow_track_suggestions": True,
        "allow_chat": True,
        "quiet_mode": False,
        "democratic_queue": False,
        "require_approval": not room.is_public,
        "max_participants": room.max_guests,
    }
    if not raw:
        # Redis expired — re-persist defaults so the next read is fast
        try:
            await redis.setex(_settings_key(room.id), ROOM_SETTINGS_TTL, json.dumps(defaults))
        except Exception:
            pass
        return defaults
    try:
        saved = json.loads(raw)
    except json.JSONDecodeError:
        return defaults
    merged = {**defaults, **saved}
    # Refresh TTL on every read so active rooms never expire
    try:
        await redis.expire(_settings_key(room.id), ROOM_SETTINGS_TTL)
    except Exception:
        pass
    return merged


def _room_state_name(room: ListeningRoom, state: dict[str, Any] | None) -> str:
    if not room.is_active:
        return "ended"
    if not room.is_public:
        return "locked"
    if not state or not state.get("track_spotify_id"):
        return "draft"
    return "live" if state.get("is_playing") else "paused"


async def _get_participant(
    db: AsyncSession, room_id: int, user_id: int
) -> RoomParticipant | None:
    return await db.scalar(
        select(RoomParticipant).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.user_id == user_id,
        )
    )


async def _clear_room_runtime_state(redis, room_id: int) -> None:
    if redis:
        await redis.delete(
            f"room:{room_id}:state",
            _queue_key(room_id),
            _pinned_key(room_id),
            _poll_key(room_id),
        )
        return
    _ROOM_PINS_FALLBACK.pop(room_id, None)
    _ROOM_POLL_FALLBACK.pop(room_id, None)


async def _serialize_room_summary(
    *,
    db: AsyncSession,
    redis,
    room: ListeningRoom,
    host: User | None,
    history_mode: bool = False,
) -> dict[str, Any]:
    participant_count = await _connected_participant_count(db, redis, room.id)
    participant_user_ids = await _participant_user_ids(db, room.id)
    current_track = await _load_room_state(redis, room.id)
    settings = await _room_settings(redis, room)
    state_name = "ended" if history_mode else _room_state_name(room, current_track)
    return {
        "room_id": room.id,
        "name": room.title,
        "description": settings.get("description", ""),
        "background_url": settings.get("background_url", ""),
        "is_public": room.is_public,
        "is_active": room.is_active,
        "invite_code": _invite_code(room.id),
        "state": state_name,
        "settings": settings,
        "created_at": room.created_at.isoformat() if room.created_at else None,
        "closed_at": room.closed_at.isoformat() if room.closed_at else None,
        "host": {
            "id": host.id if host else room.host_id,
            "username": host.username if host else None,
            "first_name": host.first_name if host else None,
            "avatar_url": host.avatar_url if host else None,
        },
        "participant_count": participant_count,
        "participant_user_ids": participant_user_ids,
        "current_track": {
            "track_spotify_id": current_track.get("track_spotify_id"),
            "track_title": current_track.get("track_title"),
            "track_artist": current_track.get("track_artist"),
            "track_cover_url": current_track.get("track_cover_url"),
            "preview_url": current_track.get("preview_url"),
            "track_duration_ms": current_track.get("track_duration_ms"),
            "position_ms": current_track.get("position_ms"),
            "is_playing": current_track.get("is_playing"),
        }
        if current_track
        else None,
    }


async def _ensure_room_participant(
    db: AsyncSession, room_id: int, user_id: int
) -> RoomParticipant:
    participant = await _get_participant(db, room_id, user_id)
    room = await db.get(ListeningRoom, room_id)
    if not participant:
        if room and room.host_id == user_id:
            participant = RoomParticipant(
                room_id=room_id,
                user_id=user_id,
                role=RoomParticipantRole.host,
                status=RoomParticipantStatus.connected,
                joined_at=datetime.utcnow(),
            )
            db.add(participant)
            await db.commit()
            return participant
    elif room and room.host_id == user_id:
        participant.role = RoomParticipantRole.host
        participant.status = RoomParticipantStatus.connected
        participant.joined_at = participant.joined_at or datetime.utcnow()
        participant.left_at = None
        await db.commit()
        return participant
    if not participant or participant.status not in {
        RoomParticipantStatus.approved,
        RoomParticipantStatus.connected,
    }:
        raise HTTPException(status_code=403, detail="Join the room first")
    return participant


async def _effective_role(redis, room: ListeningRoom, participant: RoomParticipant | None) -> str:
    if participant and (
        participant.role == RoomParticipantRole.host
        or participant.user_id == room.host_id
    ):
        return "host"
    if not participant:
        return "guest"
    raw = await redis.get(_role_key(room.id, participant.user_id))
    role = raw.decode() if isinstance(raw, bytes) else raw
    if role in {"co_host", "listener", "participant"}:
        return role
    return "participant"


async def _can_control(redis, room: ListeningRoom, participant: RoomParticipant | None) -> bool:
    return await _effective_role(redis, room, participant) in {"host", "co_host"}


async def _is_room_controller(
    redis,
    room: ListeningRoom,
    participant: RoomParticipant | None,
    user_id: int,
) -> bool:
    if room.host_id == user_id:
        return True
    return await _can_control(redis, room, participant)


async def _is_banned(redis, room_id: int, user_id: int) -> bool:
    try:
        return bool(await redis.sismember(_banned_key(room_id), str(user_id)))
    except Exception:
        return False


async def _is_muted(redis, room_id: int, user_id: int) -> bool:
    try:
        return bool(await redis.sismember(_muted_key(room_id), str(user_id)))
    except Exception:
        return False


async def _participant_user_ids(db: AsyncSession, room_id: int) -> list[int]:
    rows = await db.scalars(
        select(RoomParticipant.user_id).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.left_at.is_(None),
        )
    )
    return [int(user_id) for user_id in rows.all()]


async def _participants_payload(
    db: AsyncSession, redis, room_id: int
) -> list[dict[str, Any]]:
    rows = (
        await db.execute(
            select(RoomParticipant, User)
            .join(User, User.id == RoomParticipant.user_id)
            .where(RoomParticipant.room_id == room_id)
            .order_by(RoomParticipant.role.asc(), RoomParticipant.created_at.asc())
        )
    ).all()
    result_by_user: dict[int, dict[str, Any]] = {}
    for participant, user in rows:
        if participant.status == RoomParticipantStatus.disconnected:
            continue
        if participant.left_at is not None:
            continue
        try:
            presence = await redis.get(_presence_key(room_id, user.id))
        except Exception:
            presence = None
        role = "host" if participant.role == RoomParticipantRole.host else "participant"
        try:
            raw_role = await redis.get(_role_key(room_id, user.id))
            saved_role = raw_role.decode() if isinstance(raw_role, bytes) else raw_role
            if saved_role in {"co_host", "listener", "participant"}:
                role = saved_role
        except Exception:
            pass
        muted = await _is_muted(redis, room_id, user.id)
        banned = await _is_banned(redis, room_id, user.id)
        is_online = bool(presence)
        if participant.role != RoomParticipantRole.host and not is_online:
            continue
        payload = {
            "user_id": user.id,
            "username": user.username,
            "display_name": _display_name(user),
            "avatar_url": user.avatar_url,
            "role": role,
            "status": participant.status.value,
            "is_muted": muted,
            "is_banned": banned,
            "is_online": is_online,
            "joined_at": participant.joined_at.isoformat() + "Z"
            if participant.joined_at
            else None,
            "left_at": participant.left_at.isoformat() + "Z"
            if participant.left_at
            else None,
        }
        previous = result_by_user.get(user.id)
        if not previous:
            result_by_user[user.id] = payload
            continue
        previous_online = previous.get("is_online") == True
        if is_online and not previous_online:
            result_by_user[user.id] = payload
            continue
        previous_joined_at = (previous.get("joined_at") or "").strip()
        next_joined_at = (payload.get("joined_at") or "").strip()
        if next_joined_at > previous_joined_at:
            result_by_user[user.id] = payload
    result = list(result_by_user.values())
    result.sort(
        key=lambda item: (
            0 if item.get("role") == "host" else 1,
            0 if item.get("is_online") else 1,
            item.get("joined_at") or "",
        )
    )
    return result


async def _join_requests_payload(redis, room_id: int) -> list[dict[str, Any]]:
    requests: list[dict[str, Any]] = []
    async for key in redis.scan_iter(match=f"room:{room_id}:request:*"):
        raw = await redis.get(key)
        if not raw:
            continue
        try:
            item = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            requests.append(item)
    return requests


async def _load_room_state(redis, room_id: int) -> dict[str, Any]:
    raw_state = await redis.get(f"room:{room_id}:state")
    if not raw_state:
        return {}
    try:
        state = json.loads(raw_state)
    except json.JSONDecodeError:
        return {}
    state["position_ms"] = adjust_position(state)
    return state


async def _save_room_state(redis, room_id: int, state: dict[str, Any]) -> None:
    await redis.setex(f"room:{room_id}:state", ROOM_STATE_TTL, json.dumps(state))


async def _save_queue(redis, room_id: int, queue: list[dict[str, Any]]) -> None:
    await redis.setex(_queue_key(room_id), QUEUE_TTL, json.dumps(queue))


async def _load_queue(redis, room_id: int) -> list[dict[str, Any]]:
    raw = await redis.get(_queue_key(room_id))
    if not raw:
        return []
    try:
        queue = json.loads(raw)
    except json.JSONDecodeError:
        return []
    deduped: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in queue:
        if not isinstance(item, dict):
            continue
        track = dict(item)
        key = _queue_track_key(track)
        if key and key in seen:
            continue
        if key:
            seen.add(key)
        deduped.append(track)
    return deduped


def _queue_track_key(track: dict[str, Any]) -> str:
    title = str(track.get("title") or track.get("track_title") or "").strip().lower()
    artist = str(track.get("artist") or track.get("track_artist") or "").strip().lower()
    if title:
        return f"{title}|{artist}"
    return str(track.get("track_id") or track.get("spotify_id") or "").strip().lower()


def _queue_with_user_votes(queue: list[dict[str, Any]], user_id: int) -> list[dict[str, Any]]:
    payload: list[dict[str, Any]] = []
    for item in queue:
        votes = {int(v) for v in item.get("votes", []) if str(v).isdigit()}
        payload.append({**item, "my_vote": user_id in votes, "vote_count": len(votes)})
    return payload


async def _load_pinned(redis, room_id: int) -> list[dict[str, Any]]:
    if not redis:
        return [dict(item) for item in _ROOM_PINS_FALLBACK.get(room_id, [])]
    raw = await redis.get(_pinned_key(room_id))
    if not raw:
        return []
    try:
        pins = json.loads(raw)
    except json.JSONDecodeError:
        return []
    if not isinstance(pins, list):
        return []
    return [dict(item) for item in pins if isinstance(item, dict)]


async def _save_pinned(redis, room_id: int, pins: list[dict[str, Any]]) -> None:
    if not redis:
        _ROOM_PINS_FALLBACK[room_id] = [dict(item) for item in pins[-20:]]
        return
    await redis.setex(_pinned_key(room_id), ROOM_SETTINGS_TTL, json.dumps(pins[-20:]))


async def _load_poll(redis, room_id: int) -> dict[str, Any] | None:
    if not redis:
        poll = _ROOM_POLL_FALLBACK.get(room_id)
        return dict(poll) if poll and poll.get("active", True) else None
    raw = await redis.get(_poll_key(room_id))
    if not raw:
        return None
    try:
        poll = json.loads(raw)
        return poll if poll.get("active", True) else None
    except Exception:
        return None


async def _save_poll(redis, room_id: int, poll: dict[str, Any]) -> None:
    if not redis:
        _ROOM_POLL_FALLBACK[room_id] = dict(poll)
        return
    await redis.setex(_poll_key(room_id), ROOM_SETTINGS_TTL, json.dumps(poll))


def _poll_payload(poll: dict[str, Any] | None, user_id: int | None = None) -> dict[str, Any] | None:
    if not poll:
        return None
    votes = poll.get("votes", {})
    if not isinstance(votes, dict):
        votes = {}
    options = poll.get("options", [])
    counts = [0 for _ in options]
    my_vote = None
    for uid, raw_idx in votes.items():
        try:
            idx = int(raw_idx)
        except Exception:
            continue
        if 0 <= idx < len(counts):
            counts[idx] += 1
        if user_id is not None and str(uid) == str(user_id):
            my_vote = idx
    total = sum(counts)
    return {
        "question": poll.get("question", ""),
        "options": options,
        "counts": counts,
        "total": total,
        "my_vote": my_vote,
        "created_by": poll.get("created_by"),
        "created_by_name": poll.get("created_by_name", ""),
        "created_at": poll.get("created_at", ""),
        "active": poll.get("active", True),
    }


def _system_room_message(room_id: int, text: str) -> None:
    firebase_svc.write_room_message(
        room_id,
        {
            "sender_id": 0,
            "display_name": "MoodWave",
            "avatar_url": "",
            "text": text,
            "sent_at": datetime.utcnow().isoformat() + "Z",
            "type": "system",
        },
    )


def _build_state(event: str, payload: dict[str, Any], room: ListeningRoom, host_id: int) -> dict[str, Any]:
    track_spotify_id = payload.get("track_spotify_id") or payload.get("track_id") or room.current_track_spotify_id or ""
    position_ms = int(payload.get("position_ms") or 0)
    is_playing = bool(payload.get("is_playing", event in {"play", "track_change", "restart"}))

    if event in {"track_change", "restart"}:
        position_ms = 0
    if event == "pause":
        is_playing = False
    if event == "play":
        is_playing = True

    duration_ms = payload.get("track_duration_ms") or payload.get("duration_ms")

    return {
        "track_spotify_id": track_spotify_id,
        "track_title": payload.get("track_title", ""),
        "track_artist": payload.get("track_artist", ""),
        "track_cover_url": payload.get("track_cover_url", ""),
        "preview_url": payload.get("preview_url", ""),
        "track_duration_ms": int(duration_ms) if duration_ms else None,
        "position_ms": position_ms,
        "is_playing": is_playing,
        "updated_at": time.time(),
        "host_id": host_id,
    }


@router.post(
    "/rooms/create",
    status_code=201,
    summary="Create Live Room",
    description="Creates a Live Room for the host, closes any existing active host room, and returns WebSocket connection details.",
)
async def create_room(
    body: CreateRoomRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.max_guests > 20:
        raise HTTPException(status_code=400, detail="max_guests must be <= 20")

    room_title = (body.name or DEFAULT_ROOM_NAME).strip() or DEFAULT_ROOM_NAME
    description = (body.description or "").strip()
    background_url = _save_room_background_data_url(request, body.background_data_url) or (
        body.background_url or ""
    ).strip()
    require_approval = (
        body.require_approval if body.require_approval is not None else not body.is_public
    )

    active_rooms = (
        await db.execute(
            select(ListeningRoom).where(
                ListeningRoom.host_id == current_user.id,
                ListeningRoom.is_active == True,
            )
        )
    ).scalars().all()
    for room in active_rooms:
        room.is_active = False
        room.closed_at = datetime.utcnow()

    room = ListeningRoom(
        host_id=current_user.id,
        title=room_title,
        description=description,
        background_url=background_url,
        is_public=body.is_public,
        max_guests=body.max_guests,
        is_active=True,
    )
    db.add(room)
    await db.flush()

    db.add(
        RoomParticipant(
            room_id=room.id,
            user_id=current_user.id,
            role=RoomParticipantRole.host,
            status=RoomParticipantStatus.connected,
            joined_at=datetime.utcnow(),
        )
    )
    await db.commit()

    try:
        await request.app.state.redis.setex(
            _settings_key(room.id),
            ROOM_SETTINGS_TTL,
            json.dumps(
                {
                    "is_public": body.is_public,
                    "locked": not body.is_public,
                    "description": description,
                    "background_url": background_url,
                    "allow_track_suggestions": body.allow_track_suggestions,
                    "allow_chat": body.allow_chat,
                    "quiet_mode": body.quiet_mode,
                    "democratic_queue": body.democratic_queue,
                    "require_approval": require_approval,
                    "max_participants": body.max_guests,
                }
            ),
        )
        await request.app.state.redis.setex(
            _presence_key(room.id, current_user.id),
            75,
            json.dumps({"user_id": current_user.id, "seen_at": time.time()}),
        )
    except Exception:
        pass

    ws_token = create_ws_token(current_user.id, room.id, expires_in_seconds=24 * 60 * 60)
    return {
        "room_id": room.id,
        "invite_code": _invite_code(room.id),
        "ws_token": ws_token,
        "ws_url": _ws_url(request, room.id, ws_token),
        "name": room.title,
        "description": description,
        "background_url": background_url,
        "state": "draft" if body.is_public else "locked",
        "settings": {
            "is_public": body.is_public,
            "locked": not body.is_public,
            "description": description,
            "background_url": background_url,
            "allow_track_suggestions": body.allow_track_suggestions,
            "allow_chat": body.allow_chat,
            "quiet_mode": body.quiet_mode,
            "democratic_queue": body.democratic_queue,
            "require_approval": require_approval,
            "max_participants": body.max_guests,
        },
        "my_role": "host",
        "my_status": "connected",
        "can_control": True,
    }


@router.get(
    "/rooms/active",
    summary="List active rooms",
    description="Returns active Live Rooms visible to the current user with host information, participant counts, participants, and current track state.",
)
async def list_active_rooms(
    limit: int = Query(default=20, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(ListeningRoom, User)
            .join(User, User.id == ListeningRoom.host_id)
            .where(
                ListeningRoom.is_active == True,
                or_(
                    ListeningRoom.is_public == True,
                    ListeningRoom.host_id == current_user.id,
                    ListeningRoom.id.in_(
                        select(RoomParticipant.room_id).where(
                            RoomParticipant.user_id == current_user.id,
                            RoomParticipant.status.in_(
                                [
                                    RoomParticipantStatus.approved,
                                    RoomParticipantStatus.connected,
                                ]
                            ),
                        )
                    ),
                ),
            )
            .order_by(ListeningRoom.created_at.desc())
            .limit(limit)
        )
    ).all()

    try:
        hidden_raw = await request.app.state.redis.smembers(
            _hidden_room_history_key(current_user.id)
        )
        hidden_room_ids = {
            int(value.decode() if isinstance(value, bytes) else value)
            for value in hidden_raw
            if str(value.decode() if isinstance(value, bytes) else value).isdigit()
        }
    except Exception:
        hidden_room_ids = set()
    try:
        deleted_raw = await request.app.state.redis.smembers(
            _deleted_room_history_key()
        )
        deleted_room_ids = {
            int(value.decode() if isinstance(value, bytes) else value)
            for value in deleted_raw
            if str(value.decode() if isinstance(value, bytes) else value).isdigit()
        }
    except Exception:
        deleted_room_ids = set()

    rooms: list[dict[str, Any]] = []
    for room, host in rows:
        if room.id in hidden_room_ids or room.id in deleted_room_ids:
            continue
        rooms.append(
            await _serialize_room_summary(
                db=db,
                redis=request.app.state.redis,
                room=room,
                host=host,
            )
        )

    return {"rooms": rooms}


@router.get(
    "/rooms/history",
    summary="List room history",
    description="Returns rooms the current user created or helped manage in the past, including rooms ended with End Room.",
)
async def list_room_history(
    limit: int = Query(default=30, ge=1, le=100),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(ListeningRoom, User)
            .join(User, User.id == ListeningRoom.host_id)
            .where(
                or_(
                    ListeningRoom.host_id == current_user.id,
                    ListeningRoom.id.in_(
                        select(RoomParticipant.room_id).where(
                            RoomParticipant.user_id == current_user.id,
                        )
                    ),
                ),
            )
            .order_by(
                func.coalesce(ListeningRoom.closed_at, ListeningRoom.created_at).desc()
            )
            .limit(limit)
        )
    ).all()

    try:
        hidden_raw = await request.app.state.redis.smembers(
            _hidden_room_history_key(current_user.id)
        )
        hidden_room_ids = {
            int(value.decode() if isinstance(value, bytes) else value)
            for value in hidden_raw
            if str(value.decode() if isinstance(value, bytes) else value).isdigit()
        }
    except Exception:
        hidden_room_ids = set()
    try:
        deleted_raw = await request.app.state.redis.smembers(
            _deleted_room_history_key()
        )
        deleted_room_ids = {
            int(value.decode() if isinstance(value, bytes) else value)
            for value in deleted_raw
            if str(value.decode() if isinstance(value, bytes) else value).isdigit()
        }
    except Exception:
        deleted_room_ids = set()

    rooms: list[dict[str, Any]] = []
    for room, host in rows:
        if room.id in hidden_room_ids or room.id in deleted_room_ids:
            continue
        rooms.append(
            await _serialize_room_summary(
                db=db,
                redis=request.app.state.redis,
                room=room,
                host=host,
                history_mode=True,
            )
        )
    return {"rooms": rooms}


@router.get(
    "/rooms/{room_id}",
    summary="Get room details",
    description="Returns details for an active Live Room, including host info, invite code, and current playback state.",
)
async def room_info(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")

    host = await db.get(User, room.host_id)
    current_track = await _load_room_state(request.app.state.redis, room.id)
    participant = await _get_participant(db, room.id, current_user.id)
    settings = await _room_settings(request.app.state.redis, room)
    active_poll = await _load_poll(request.app.state.redis, room.id)
    # Backfill DB column for rooms created before the background_url migration
    bg_from_settings = settings.get("background_url", "")
    if not getattr(room, "background_url", None) and bg_from_settings:
        room.background_url = bg_from_settings
        await db.commit()
    if participant and participant.status == RoomParticipantStatus.connected:
        await request.app.state.redis.setex(
            _presence_key(room.id, current_user.id),
            75,
            json.dumps({"user_id": current_user.id, "seen_at": time.time()}),
        )
    participants = await _participants_payload(db, request.app.state.redis, room.id)
    participant_count = sum(1 for person in participants if person.get("is_online"))
    can_control = await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    )
    join_requests = (
        await _join_requests_payload(request.app.state.redis, room.id)
        if can_control
        else []
    )
    ws_token = None
    if participant and participant.status in {
        RoomParticipantStatus.connected,
        RoomParticipantStatus.approved,
    }:
        ws_token = create_ws_token(current_user.id, room_id, expires_in_seconds=24 * 60 * 60)
    return {
        "room_id": room.id,
        "name": room.title,
        "description": settings.get("description", ""),
        "background_url": settings.get("background_url", ""),
        "is_public": room.is_public,
        "is_active": room.is_active,
        "state": _room_state_name(room, current_track),
        "max_guests": room.max_guests,
        "invite_code": _invite_code(room.id),
        "settings": settings,
        "server_time": time.time(),
        "my_role": await _effective_role(request.app.state.redis, room, participant),
        "my_status": participant.status.value if participant else "preview",
        "can_control": can_control,
        "participant_count": participant_count,
        "participants": participants,
        "join_requests": join_requests,
        "active_poll": _poll_payload(active_poll, current_user.id),
        "host": {
            "id": host.id if host else room.host_id,
            "username": host.username if host else None,
            "first_name": host.first_name if host else None,
            "avatar_url": host.avatar_url if host else None,
        },
        "current_track": current_track or None,
        "ws_token": ws_token,
        "ws_url": _ws_url(request, room_id, ws_token) if ws_token else None,
    }


@router.post("/rooms/{room_id}/join", summary="Join a public or approved room")
async def join_room(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    if await _is_banned(request.app.state.redis, room_id, current_user.id):
        raise HTTPException(status_code=403, detail="You are banned from this room")

    participant = await _get_participant(db, room_id, current_user.id)
    if room.host_id == current_user.id:
        if participant:
            participant.status = RoomParticipantStatus.connected
            participant.left_at = None
        room.closed_at = None
        await db.commit()
    elif participant and participant.status in {
        RoomParticipantStatus.approved,
        RoomParticipantStatus.connected,
    }:
        participant.status = RoomParticipantStatus.connected
        participant.joined_at = participant.joined_at or datetime.utcnow()
        participant.left_at = None
        await db.commit()
    elif room.is_public:
        # Public rooms: always allow direct join regardless of require_approval setting
        connected_guests = await _connected_guest_count(db, room_id)
        if connected_guests >= room.max_guests:
            raise HTTPException(status_code=403, detail="Room is full")
        if participant:
            participant.role = RoomParticipantRole.guest
            participant.status = RoomParticipantStatus.connected
            participant.joined_at = datetime.utcnow()
            participant.left_at = None
        else:
            db.add(
                RoomParticipant(
                    room_id=room_id,
                    user_id=current_user.id,
                    role=RoomParticipantRole.guest,
                    status=RoomParticipantStatus.connected,
                    joined_at=datetime.utcnow(),
                )
            )
        await db.commit()
        _system_room_message(room_id, f"{_display_name(current_user)} joined")
    else:
        raise HTTPException(status_code=403, detail="room_locked")

    await request.app.state.redis.setex(
        _presence_key(room_id, current_user.id),
        75,
        json.dumps({"user_id": current_user.id, "seen_at": time.time()}),
    )
    ws_token = create_ws_token(current_user.id, room_id, expires_in_seconds=24 * 60 * 60)
    await manager.broadcast(room_id, {"event": "participant_joined", "user_id": current_user.id})
    return {"message": "joined", "ws_token": ws_token, "ws_url": _ws_url(request, room_id, ws_token)}


@router.get("/rooms/{room_id}/participants", summary="Get room participants")
async def get_room_participants(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    return {"participants": await _participants_payload(db, request.app.state.redis, room_id)}


@router.get("/rooms/{room_id}/join-requests", summary="Get pending room join requests")
async def get_room_join_requests(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Not allowed")
    return {"requests": await _join_requests_payload(request.app.state.redis, room_id)}


@router.patch("/rooms/{room_id}/settings", summary="Update room settings")
async def update_room_settings(
    room_id: int,
    body: RoomSettingsUpdateRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only hosts can update room settings")
    settings = await _room_settings(request.app.state.redis, room)
    updates = {key: value for key, value in body.dict().items() if value is not None}
    if "name" in updates:
        room.title = str(updates.pop("name")).strip() or room.title
    if "description" in updates:
        updates["description"] = str(updates["description"]).strip()
        room.description = updates["description"]
    if "background_data_url" in updates:
        updates["background_url"] = _save_room_background_data_url(
            request, updates.pop("background_data_url")
        )
    if "background_url" in updates:
        updates["background_url"] = str(updates["background_url"]).strip()
        room.background_url = updates["background_url"]
    if "is_public" in updates:
        room.is_public = bool(updates["is_public"])
        updates.setdefault("locked", not room.is_public)
        # When making a room public, clear require_approval unless host explicitly set it
        if room.is_public and "require_approval" not in updates:
            updates["require_approval"] = False
    if "max_participants" in updates:
        room.max_guests = int(updates["max_participants"])
    settings.update(updates)
    await request.app.state.redis.setex(
        _settings_key(room_id),
        ROOM_SETTINGS_TTL,
        json.dumps(settings),
    )
    await db.commit()
    await manager.broadcast(room_id, {"event": "settings_updated", "settings": settings})
    return {
        "settings": settings,
        "is_public": room.is_public,
        "name": room.title,
        "description": settings.get("description", ""),
        "background_url": settings.get("background_url", ""),
    }


@router.post("/rooms/{room_id}/participants/{user_id}/role", summary="Set participant room role")
async def set_participant_role(
    room_id: int,
    user_id: int,
    body: RoomRoleRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    if room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only host can change roles")
    target = await _get_participant(db, room_id, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="Participant not found")
    if target.role == RoomParticipantRole.host:
        raise HTTPException(status_code=400, detail="Cannot change host role")
    await request.app.state.redis.setex(_role_key(room_id, user_id), ROOM_STATE_TTL, body.role)
    await manager.broadcast(room_id, {"event": "role_updated", "user_id": user_id, "role": body.role})
    return {"ok": True, "role": body.role}


@router.post("/rooms/{room_id}/participants/{user_id}/kick", summary="Kick participant")
async def kick_participant(
    room_id: int,
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only hosts can kick")
    target = await _get_participant(db, room_id, user_id)
    if not target or target.role == RoomParticipantRole.host:
        raise HTTPException(status_code=400, detail="Cannot kick this user")
    target.status = RoomParticipantStatus.disconnected
    target.left_at = datetime.utcnow()
    await db.commit()
    await manager.broadcast(room_id, {"event": "participant_kicked", "user_id": user_id})
    return {"ok": True}


@router.post("/rooms/{room_id}/participants/{user_id}/ban", summary="Ban participant")
async def ban_participant(
    room_id: int,
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only hosts can ban")
    target = await _get_participant(db, room_id, user_id)
    if target and target.role == RoomParticipantRole.host:
        raise HTTPException(status_code=400, detail="Cannot ban host")
    await request.app.state.redis.sadd(_banned_key(room_id), str(user_id))
    if target:
        target.status = RoomParticipantStatus.disconnected
        target.left_at = datetime.utcnow()
        await db.commit()
    await manager.broadcast(room_id, {"event": "participant_banned", "user_id": user_id})
    return {"ok": True}


@router.post("/rooms/{room_id}/participants/{user_id}/mute", summary="Mute participant")
async def mute_participant(
    room_id: int,
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only hosts can mute")
    await request.app.state.redis.sadd(_muted_key(room_id), str(user_id))
    return {"ok": True}


@router.delete("/rooms/{room_id}/participants/{user_id}/mute", summary="Unmute participant")
async def unmute_participant(
    room_id: int,
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only hosts can unmute")
    await request.app.state.redis.srem(_muted_key(room_id), str(user_id))
    return {"ok": True}


@router.post("/rooms/{room_id}/heartbeat", summary="Keep room participant online")
async def room_heartbeat(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    if await _is_banned(request.app.state.redis, room_id, current_user.id):
        raise HTTPException(status_code=403, detail="You are banned from this room")
    participant = await _ensure_room_participant(db, room_id, current_user.id)
    participant.status = RoomParticipantStatus.connected
    participant.left_at = None
    await db.commit()
    await request.app.state.redis.setex(
        _presence_key(room_id, current_user.id),
        75,
        json.dumps({"user_id": current_user.id, "seen_at": time.time()}),
    )
    return {"ok": True, "server_time": time.time()}


@router.post("/rooms/{room_id}/leave", summary="Leave room")
async def leave_room(
    request: Request,
    room_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if participant:
        participant.status = RoomParticipantStatus.disconnected
        participant.left_at = datetime.utcnow()
    if room.host_id == current_user.id:
        room.closed_at = datetime.utcnow()
        room.current_track_spotify_id = None
        await _clear_room_runtime_state(request.app.state.redis, room_id)
        await manager.broadcast(room_id, {"event": "room_closed"})
    else:
        await manager.broadcast(room_id, {"event": "guest_left", "user_id": current_user.id})
    await db.commit()
    return {"ok": True}


@router.post(
    "/rooms/{room_id}/join-request",
    status_code=202,
    summary="Request room join",
    description="Creates a pending join request for a Live Room, stores it in Redis, and notifies the host.",
)
async def join_request(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    if await _is_banned(request.app.state.redis, room_id, current_user.id):
        raise HTTPException(status_code=403, detail="You are banned from this room")

    connected_guests = await _connected_guest_count(db, room_id)
    if connected_guests >= room.max_guests:
        raise HTTPException(status_code=403, detail="Room is full")

    participant = await db.scalar(
        select(RoomParticipant).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.user_id == current_user.id,
        )
    )
    if participant and participant.status in {
        RoomParticipantStatus.pending,
        RoomParticipantStatus.approved,
        RoomParticipantStatus.connected,
    }:
        return {
            "message": "Already requested or joined",
            "status": participant.status.value,
        }

    if participant:
        participant.role = RoomParticipantRole.guest
        participant.status = RoomParticipantStatus.pending
        participant.left_at = None
    else:
        db.add(
            RoomParticipant(
                room_id=room_id,
                user_id=current_user.id,
                role=RoomParticipantRole.guest,
                status=RoomParticipantStatus.pending,
            )
        )
    await db.commit()

    request_key = _request_key(room_id, current_user.id)
    await request.app.state.redis.setex(
        request_key,
        REQUEST_TTL,
        json.dumps(
            {
                "user_id": current_user.id,
                "username": current_user.username,
                "first_name": current_user.first_name,
            }
        ),
    )

    host = await db.get(User, room.host_id)
    await firebase_svc.send_push_notification(
        token=host.fcm_token if host else None,
        title="Join request",
        body=f"🎵 {_display_name(current_user)} wants to join your listening party",
        data={"event": "join_request", "room_id": room_id, "user_id": current_user.id},
    )
    return {"message": "Request sent, waiting for host approval"}


@router.post(
    "/rooms/{room_id}/join-approve",
    summary="Approve room join",
    description="Approves a pending room join request, generates a short-lived WebSocket token, and notifies the guest.",
)
async def join_approve(
    room_id: int,
    body: JoinApprovalRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Not allowed")

    request_key = _request_key(room_id, body.user_id)
    await request.app.state.redis.delete(request_key)

    participant = await db.scalar(
        select(RoomParticipant).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.user_id == body.user_id,
        )
    )
    if not participant:
        participant = RoomParticipant(
            room_id=room_id,
            user_id=body.user_id,
            role=RoomParticipantRole.guest,
            status=RoomParticipantStatus.approved,
        )
        db.add(participant)
    else:
        participant.role = RoomParticipantRole.guest
        participant.status = RoomParticipantStatus.approved
        participant.left_at = None
    await db.commit()

    ws_token = create_ws_token(body.user_id, room_id, expires_in_seconds=60)
    guest = await db.get(User, body.user_id)
    await firebase_svc.send_push_notification(
        token=guest.fcm_token if guest else None,
        title="Join approved",
        body="✅ Host approved! Join now",
        data={"event": "join_approved", "room_id": room_id, "ws_token": ws_token},
    )
    await request.app.state.redis.delete(request_key)
    _system_room_message(room_id, f"{_display_name(guest) if guest else 'Guest'} was approved")
    return {"message": "approved", "ws_token": ws_token}


@router.post(
    "/rooms/{room_id}/join-decline",
    summary="Decline room join",
    description="Declines a pending room join request, updates participant state, and notifies the guest.",
)
async def join_decline(
    room_id: int,
    body: JoinDeclineRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Not allowed")

    await request.app.state.redis.delete(_request_key(room_id, body.user_id))

    participant = await db.scalar(
        select(RoomParticipant).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.user_id == body.user_id,
        )
    )
    if participant:
        participant.status = RoomParticipantStatus.disconnected
        participant.left_at = datetime.utcnow()
        await db.commit()

    guest = await db.get(User, body.user_id)
    await firebase_svc.send_push_notification(
        token=guest.fcm_token if guest else None,
        title="Join declined",
        body="❌ Host declined your request",
        data={"event": "join_declined", "room_id": room_id},
    )
    return {"message": "declined"}


@router.post("/rooms/{room_id}/messages", status_code=201, summary="Send room chat message")
async def send_room_message(
    room_id: int,
    request: Request,
    body: RoomMessageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    await _ensure_room_participant(db, room_id, current_user.id)
    settings = await _room_settings(request.app.state.redis, room)
    role = await _effective_role(
        request.app.state.redis,
        room,
        await _get_participant(db, room_id, current_user.id),
    )
    if await _is_muted(request.app.state.redis, room_id, current_user.id):
        raise HTTPException(status_code=403, detail="You are muted in this room")
    if settings.get("quiet_mode") and role not in {"host", "co_host"}:
        raise HTTPException(status_code=403, detail="Only hosts can chat in quiet mode")
    if settings.get("allow_chat") is False:
        raise HTTPException(status_code=403, detail="Room chat is disabled")
    message = {
        "sender_id": current_user.id,
        "display_name": _display_name(current_user),
        "avatar_url": current_user.avatar_url or "",
        "role": role,
        "text": body.text.strip(),
        "sent_at": datetime.utcnow().isoformat() + "Z",
        "type": "text",
    }
    message_id = firebase_svc.write_room_message(room_id, message)
    if message_id:
        message["message_id"] = message_id
    await manager.broadcast(room_id, {"event": "message_created", "message": message})
    return {"ok": True, "message": message}


@router.get("/rooms/{room_id}/messages", summary="Get room chat messages")
async def get_room_messages(
    room_id: int,
    limit: int = Query(default=50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not room.is_public and not participant:
        raise HTTPException(status_code=403, detail="Join the room first")
    messages = firebase_svc.get_room_messages(room_id, limit=limit)
    return {"messages": messages}


@router.get("/rooms/{room_id}/pinned", summary="Get pinned room messages")
async def get_room_pinned_messages(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not room.is_public and not participant:
        raise HTTPException(status_code=403, detail="Join the room first")
    pins = await _load_pinned(request.app.state.redis, room_id)
    return {"pinned": pins}


@router.patch("/rooms/{room_id}/messages/{message_id}", summary="Edit room chat message")
async def update_room_chat_message(
    room_id: int,
    message_id: str,
    body: RoomMessageUpdateRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not participant:
        raise HTTPException(status_code=403, detail="Join the room first")
    message = firebase_svc.get_room_message(room_id, message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    can_control = await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    )
    sender_id = int((message or {}).get("sender_id") or 0)
    if not can_control and sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only moderators or author can edit")
    if (message.get("type") or "text") != "text":
        raise HTTPException(status_code=400, detail="Only text messages can be edited")
    updated = firebase_svc.update_room_message(
        room_id,
        message_id,
        {
            "text": body.text.strip(),
            "edited_at": datetime.utcnow().isoformat() + "Z",
            "edited_by": current_user.id,
        },
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Message not found")
    await manager.broadcast(room_id, {"event": "message_updated", "message": updated})
    return {"ok": True, "message": updated}


@router.post("/rooms/{room_id}/pinned", status_code=201, summary="Pin room message")
async def pin_room_message(
    room_id: int,
    body: RoomPinRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not participant and room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Join the room first")
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only moderators can pin messages")
    pins = await _load_pinned(request.app.state.redis, room_id)
    pins = [pin for pin in pins if pin.get("message_id") != body.message_id]
    entry = {
        "message_id": body.message_id,
        "preview": (body.preview or "").strip()[:180],
        "pinned_by": current_user.id,
        "pinned_by_name": _display_name(current_user),
        "pinned_at": datetime.utcnow().isoformat() + "Z",
    }
    pins.append(entry)
    await _save_pinned(request.app.state.redis, room_id, pins)
    await manager.broadcast(room_id, {"event": "pinned_updated", "pinned": pins})
    return {"ok": True, "pinned": pins}


@router.delete("/rooms/{room_id}/pinned/{message_id}", summary="Unpin room message")
async def unpin_room_message(
    room_id: int,
    message_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not participant:
        raise HTTPException(status_code=403, detail="Join the room first")
    can_control = await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    )
    pins = await _load_pinned(request.app.state.redis, room_id)
    target = next((pin for pin in pins if pin.get("message_id") == message_id), None)
    if target and not can_control and target.get("pinned_by") != current_user.id:
        raise HTTPException(status_code=403, detail="Only moderators or pin author can unpin")
    pins = [pin for pin in pins if pin.get("message_id") != message_id]
    await _save_pinned(request.app.state.redis, room_id, pins)
    await manager.broadcast(room_id, {"event": "pinned_updated", "pinned": pins})
    return {"ok": True, "pinned": pins}


@router.get("/rooms/{room_id}/poll", summary="Get active room poll")
async def get_room_poll(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    await _ensure_room_participant(db, room_id, current_user.id)
    poll = await _load_poll(request.app.state.redis, room_id)
    return {"poll": _poll_payload(poll, current_user.id)}


@router.post("/rooms/{room_id}/poll", status_code=201, summary="Create room poll")
async def create_room_poll(
    room_id: int,
    body: RoomPollRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only host or co-host can create polls")
    options = [option.strip() for option in body.options if option.strip()]
    if len(options) < 2:
        raise HTTPException(status_code=400, detail="Poll needs at least 2 options")
    poll = {
        "question": body.question.strip(),
        "options": options[:6],
        "votes": {},
        "created_by": current_user.id,
        "created_by_name": _display_name(current_user),
        "created_at": datetime.utcnow().isoformat() + "Z",
        "active": True,
    }
    await _save_poll(request.app.state.redis, room_id, poll)
    await manager.broadcast(room_id, {"event": "poll_updated", "poll": _poll_payload(poll)})
    _system_room_message(room_id, f"{_display_name(current_user)} started a poll")
    return {"poll": _poll_payload(poll, current_user.id)}


@router.post("/rooms/{room_id}/poll/vote", summary="Vote in room poll")
async def vote_room_poll(
    room_id: int,
    body: RoomPollVoteRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    await _ensure_room_participant(db, room_id, current_user.id)
    poll = await _load_poll(request.app.state.redis, room_id)
    if not poll:
        raise HTTPException(status_code=404, detail="No active poll")
    options = poll.get("options", [])
    if body.option_index >= len(options):
        raise HTTPException(status_code=400, detail="Invalid poll option")
    votes = poll.get("votes", {})
    if not isinstance(votes, dict):
        votes = {}
    votes[str(current_user.id)] = body.option_index
    poll["votes"] = votes
    await _save_poll(request.app.state.redis, room_id, poll)
    await manager.broadcast(room_id, {"event": "poll_updated", "poll": _poll_payload(poll)})
    return {"poll": _poll_payload(poll, current_user.id)}


@router.delete("/rooms/{room_id}/poll", summary="Close active room poll")
async def close_room_poll(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only host or co-host can close polls")
    if request.app.state.redis:
        await request.app.state.redis.delete(_poll_key(room_id))
    else:
        _ROOM_POLL_FALLBACK.pop(room_id, None)
    await manager.broadcast(room_id, {"event": "poll_updated", "poll": None})
    return {"ok": True, "poll": None}


@router.delete("/rooms/{room_id}/messages/{message_id}", summary="Delete room chat message")
async def delete_room_chat_message(
    room_id: int,
    message_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not participant:
        raise HTTPException(status_code=403, detail="Join the room first")
    message = firebase_svc.get_room_message(room_id, message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    can_control = await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    )
    sender_id = int((message or {}).get("sender_id") or 0)
    if not can_control and sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only moderators or author can delete")
    firebase_svc.delete_room_message(room_id, message_id)
    pins = await _load_pinned(request.app.state.redis, room_id)
    pins = [pin for pin in pins if pin.get("message_id") != message_id]
    await _save_pinned(request.app.state.redis, room_id, pins)
    await manager.broadcast(
        room_id,
        {"event": "message_deleted", "message_id": message_id, "pinned": pins},
    )
    return {"ok": True, "pinned": pins}


@router.get("/rooms/{room_id}/playback", summary="Get synchronized playback state")
async def get_room_playback(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    state = await _load_room_state(request.app.state.redis, room_id)
    return {"state": state, "server_time": time.time()}


@router.post("/rooms/{room_id}/playback", summary="Update synchronized playback state")
async def update_room_playback(
    room_id: int,
    body: PlaybackUpdateRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _ensure_room_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only host can control playback")

    current_state = await _load_room_state(request.app.state.redis, room_id)
    payload = {
        **current_state,
        **{
            key: value
            for key, value in body.dict().items()
            if value is not None and key != "event"
        },
    }
    state = _build_state(body.event, payload, room, current_user.id)
    await _save_room_state(request.app.state.redis, room_id, state)
    room.current_track_spotify_id = state.get("track_spotify_id") or None
    room.closed_at = None
    await db.commit()
    await manager.broadcast(room_id, {"event": "sync", "state": state})
    return {"state": state, "server_time": time.time()}


@router.get("/rooms/{room_id}/queue", summary="Get room track queue")
async def get_room_queue(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    await _ensure_room_participant(db, room_id, current_user.id)
    queue = await _load_queue(request.app.state.redis, room_id)
    return {"queue": _queue_with_user_votes(queue, current_user.id)}


@router.post("/rooms/{room_id}/queue", status_code=201, summary="Add track to room queue")
async def add_to_room_queue(
    room_id: int,
    body: QueueTrackRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _ensure_room_participant(db, room_id, current_user.id)
    settings = await _room_settings(request.app.state.redis, room)
    can_control = await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    )
    if not can_control and not settings.get("allow_track_suggestions", True):
        raise HTTPException(status_code=403, detail="Track suggestions are disabled")
    queue = await _load_queue(request.app.state.redis, room_id)
    new_item = {
        "track_id": body.track_id,
        "title": body.title,
        "artist": body.artist,
        "cover_url": body.cover_url,
        "preview_url": body.preview_url,
        "duration_ms": body.duration_ms,
        "status": "queued" if can_control else "suggested",
        "votes": [],
        "vote_count": 0,
        "added_by_id": current_user.id,
        "added_by": _display_name(current_user),
        "added_at": datetime.utcnow().isoformat() + "Z",
    }
    new_key = _queue_track_key(new_item)
    if not new_key or all(_queue_track_key(item) != new_key for item in queue):
        queue.append(new_item)
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id), "queue_length": len(queue), "status": new_item["status"]}


@router.post("/rooms/{room_id}/queue/bulk", status_code=201, summary="Add multiple tracks to room queue")
async def add_bulk_to_room_queue(
    room_id: int,
    body: QueueBulkRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _ensure_room_participant(db, room_id, current_user.id)
    settings = await _room_settings(request.app.state.redis, room)
    can_control = await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    )
    if not can_control and not settings.get("allow_track_suggestions", True):
        raise HTTPException(status_code=403, detail="Track suggestions are disabled")
    queue = await _load_queue(request.app.state.redis, room_id)
    now = datetime.utcnow().isoformat() + "Z"
    status = "queued" if can_control else "suggested"
    existing_keys = {_queue_track_key(item) for item in queue}
    added = 0
    for t in body.tracks:
        item = {
            "track_id": t.track_id,
            "title": t.title,
            "artist": t.artist,
            "cover_url": t.cover_url,
            "preview_url": t.preview_url,
            "duration_ms": t.duration_ms,
            "status": status,
            "votes": [],
            "vote_count": 0,
            "added_by_id": current_user.id,
            "added_by": _display_name(current_user),
            "added_at": now,
        }
        key = _queue_track_key(item)
        if key and key in existing_keys:
            continue
        if key:
            existing_keys.add(key)
        queue.append(item)
        added += 1
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id), "queue_length": len(queue), "added": added}


@router.delete("/rooms/{room_id}/queue/{track_index}", summary="Remove track from queue (host only)")
async def remove_from_room_queue(
    room_id: int,
    track_index: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only host can remove from queue")
    queue = await _load_queue(request.app.state.redis, room_id)
    if 0 <= track_index < len(queue):
        queue.pop(track_index)
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id)}


@router.post("/rooms/{room_id}/queue/reorder", summary="Reorder room queue (host only)")
async def reorder_room_queue(
    room_id: int,
    body: QueueReorderRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only host can reorder queue")
    queue = await _load_queue(request.app.state.redis, room_id)
    if body.from_index >= len(queue) or body.to_index >= len(queue):
        raise HTTPException(status_code=400, detail="Invalid queue index")
    item = queue.pop(body.from_index)
    queue.insert(body.to_index, item)
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id)}


@router.post("/rooms/{room_id}/queue/{track_index}/play", summary="Play queue item (host only)")
async def play_room_queue_item(
    room_id: int,
    track_index: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only host can control playback")
    queue = await _load_queue(request.app.state.redis, room_id)
    if not 0 <= track_index < len(queue):
        raise HTTPException(status_code=400, detail="Invalid queue index")
    for item in queue:
        if item.get("status") == "playing":
            item["status"] = "played"
    item = queue[track_index]
    item["status"] = "playing"
    state = _build_state(
        "track_change",
        {
            "track_id": item.get("track_id"),
            "track_title": item.get("title", ""),
            "track_artist": item.get("artist", ""),
            "track_cover_url": item.get("cover_url", ""),
            "preview_url": item.get("preview_url", ""),
            "track_duration_ms": item.get("duration_ms"),
            "position_ms": 0,
            "is_playing": True,
        },
        room,
        current_user.id,
    )
    await _save_queue(request.app.state.redis, room_id, queue)
    await _save_room_state(request.app.state.redis, room_id, state)
    room.current_track_spotify_id = state.get("track_spotify_id") or None
    room.closed_at = None
    await db.commit()
    await manager.broadcast(room_id, {"event": "sync", "state": state})
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    _system_room_message(room_id, f"Host started {item.get('title', 'a track')}")
    return {"state": state, "queue": _queue_with_user_votes(queue, current_user.id)}


@router.post("/rooms/{room_id}/queue/{track_index}/approve", summary="Approve suggested queue item")
async def approve_queue_item(
    room_id: int,
    track_index: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only hosts can approve suggestions")
    queue = await _load_queue(request.app.state.redis, room_id)
    if not 0 <= track_index < len(queue):
        raise HTTPException(status_code=400, detail="Invalid queue index")
    queue[track_index]["status"] = "queued"
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id)}


@router.delete("/rooms/{room_id}/queue/{track_index}/suggestion", summary="Reject suggested queue item")
async def reject_queue_item(
    room_id: int,
    track_index: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    if not await _is_room_controller(
        request.app.state.redis, room, participant, current_user.id
    ):
        raise HTTPException(status_code=403, detail="Only hosts can reject suggestions")
    queue = await _load_queue(request.app.state.redis, room_id)
    if not 0 <= track_index < len(queue):
        raise HTTPException(status_code=400, detail="Invalid queue index")
    queue.pop(track_index)
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id)}


@router.post("/rooms/{room_id}/queue/{track_index}/vote", summary="Vote for queue item")
async def vote_queue_item(
    room_id: int,
    track_index: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    await _ensure_room_participant(db, room_id, current_user.id)
    settings = await _room_settings(request.app.state.redis, room)
    if not settings.get("democratic_queue", False):
        raise HTTPException(status_code=403, detail="Democratic queue is disabled")
    queue = await _load_queue(request.app.state.redis, room_id)
    if not 0 <= track_index < len(queue):
        raise HTTPException(status_code=400, detail="Invalid queue index")
    votes = {int(v) for v in queue[track_index].get("votes", []) if str(v).isdigit()}
    votes.add(current_user.id)
    queue[track_index]["votes"] = sorted(votes)
    queue[track_index]["vote_count"] = len(votes)
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id), "vote_count": len(votes)}


@router.delete("/rooms/{room_id}/queue/{track_index}/vote", summary="Remove vote for queue item")
async def unvote_queue_item(
    room_id: int,
    track_index: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    await _ensure_room_participant(db, room_id, current_user.id)
    queue = await _load_queue(request.app.state.redis, room_id)
    if not 0 <= track_index < len(queue):
        raise HTTPException(status_code=400, detail="Invalid queue index")
    votes = {int(v) for v in queue[track_index].get("votes", []) if str(v).isdigit()}
    votes.discard(current_user.id)
    queue[track_index]["votes"] = sorted(votes)
    queue[track_index]["vote_count"] = len(votes)
    await _save_queue(request.app.state.redis, room_id, queue)
    await manager.broadcast(room_id, {"event": "queue_updated", "queue": queue})
    return {"ok": True, "queue": _queue_with_user_votes(queue, current_user.id), "vote_count": len(votes)}


@router.post(
    "/rooms/{room_id}/close",
    summary="Close room",
    description="Closes an active Live Room owned by the current host and broadcasts a room-closed event.",
)
async def close_room(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    if room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not host")

    room.current_track_spotify_id = None
    room.closed_at = datetime.utcnow()
    await db.commit()
    await manager.broadcast(room_id, {"event": "room_closed"})

    # Reset the live session but keep the room discoverable in Party.
    await _clear_room_runtime_state(request.app.state.redis, room_id)

    return {"message": "Room ended"}


@router.delete(
    "/rooms/{room_id}",
    summary="Delete room from history",
    description="Permanently removes a room from Party/history for everyone. Allowed for host or co-host.",
)
async def delete_room(
    room_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    participant = await _get_participant(db, room_id, current_user.id)
    can_manage = await _is_room_controller(
        request.app.state.redis,
        room,
        participant,
        current_user.id,
    )
    if not can_manage:
        if participant:
            await request.app.state.redis.sadd(
                _hidden_room_history_key(current_user.id), str(room_id)
            )
            await request.app.state.redis.expire(
                _hidden_room_history_key(current_user.id), 60 * 60 * 24 * 365
            )
            return {"ok": True, "room_id": room_id, "mode": "hidden"}
        raise HTTPException(status_code=403, detail="Not allowed")

    room.is_active = False
    room.closed_at = room.closed_at or datetime.utcnow()
    room.current_track_spotify_id = None
    await db.commit()
    await request.app.state.redis.sadd(_deleted_room_history_key(), str(room_id))
    await request.app.state.redis.expire(
        _deleted_room_history_key(), 60 * 60 * 24 * 365
    )
    await request.app.state.redis.sadd(
        _hidden_room_history_key(current_user.id), str(room_id)
    )
    await request.app.state.redis.expire(
        _hidden_room_history_key(current_user.id), 60 * 60 * 24 * 365
    )
    await _clear_room_runtime_state(request.app.state.redis, room_id)
    await manager.broadcast(room_id, {"event": "room_deleted"})
    return {"ok": True, "room_id": room_id}


@router.websocket("/ws/rooms/{room_id}")
async def room_websocket(
    room_id: int,
    websocket: WebSocket,
    db: AsyncSession = Depends(get_db),
):
    token = websocket.query_params.get("token")
    payload = verify_ws_token(token or "")
    if not payload or int(payload.get("room_id", -1)) != room_id:
        await websocket.close(code=4001)
        return

    user_id = int(payload["sub"])
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        await websocket.close(code=4004)
        return

    participant = await db.scalar(
        select(RoomParticipant).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.user_id == user_id,
        )
    )
    if not participant:
        await websocket.close(code=4001)
        return

    user = await db.get(User, user_id)
    await manager.connect(room_id, user_id, websocket)

    participant.status = RoomParticipantStatus.connected
    participant.joined_at = datetime.utcnow()
    participant.left_at = None
    await db.commit()

    redis = websocket.app.state.redis
    state = await _load_room_state(redis, room_id)
    await websocket.send_json({"event": "sync", "state": state})

    await manager.broadcast(
        room_id,
        {
            "event": "guest_joined",
            "user_id": user_id,
            "username": user.username if user else str(user_id),
        },
        exclude_user_id=user_id,
    )

    try:
        while True:
            data = await websocket.receive_json()
            event = data.get("event")
            participant = await db.scalar(
                select(RoomParticipant).where(
                    RoomParticipant.room_id == room_id,
                    RoomParticipant.user_id == user_id,
                )
            )
            if not participant:
                await websocket.close(code=4001)
                return

            if event in {"play", "pause", "seek", "track_change", "heartbeat"} and await _is_room_controller(
                redis,
                room,
                participant,
                user_id,
            ):
                state = _build_state(event, data, room, user_id)
                await _save_room_state(redis, room_id, state)
                room.current_track_spotify_id = state.get("track_spotify_id") or None
                room.closed_at = None
                await db.commit()
                await manager.broadcast(
                    room_id,
                    {"event": "sync", "state": state},
                    exclude_user_id=user_id,
                )
            elif event == "ping":
                await websocket.send_json({"event": "pong", "server_time": time.time()})
    except WebSocketDisconnect:
        manager.disconnect(room_id, user_id)
        room = await db.get(ListeningRoom, room_id)
        if room and room.host_id != user_id:
            await manager.broadcast(room_id, {"event": "guest_left", "user_id": user_id})
