from __future__ import annotations

import json
import time
from datetime import datetime
from typing import Any

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
REQUEST_TTL = 300
DEFAULT_ROOM_NAME = "Listening Party"


class CreateRoomRequest(BaseModel):
    name: str | None = Field(default=None, max_length=255)
    is_public: bool = False
    max_guests: int = Field(default=10, ge=1)


class JoinApprovalRequest(BaseModel):
    user_id: int


class JoinDeclineRequest(BaseModel):
    user_id: int


class RoomMessageRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


class QueueTrackRequest(BaseModel):
    track_id: str
    title: str
    artist: str
    cover_url: str | None = None
    duration_ms: int | None = None


def _invite_code(room_id: int) -> str:
    return f"MW-{room_id:04X}"


def _ws_url(room_id: int, token: str) -> str:
    return f"ws://localhost:8000/ws/rooms/{room_id}?token={token}"


def _request_key(room_id: int, user_id: int) -> str:
    return f"room:{room_id}:request:{user_id}"


def _display_name(user: User) -> str:
    return user.first_name or user.display_name or user.username


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


async def _connected_participant_count(db: AsyncSession, room_id: int) -> int:
    return int(
        await db.scalar(
            select(func.count(RoomParticipant.id)).where(
                RoomParticipant.room_id == room_id,
                RoomParticipant.status == RoomParticipantStatus.connected,
            )
        )
        or 0
    )


async def _participant_user_ids(db: AsyncSession, room_id: int) -> list[int]:
    rows = await db.scalars(
        select(RoomParticipant.user_id).where(
            RoomParticipant.room_id == room_id,
            RoomParticipant.left_at.is_(None),
        )
    )
    return [int(user_id) for user_id in rows.all()]


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


def _build_state(event: str, payload: dict[str, Any], room: ListeningRoom, host_id: int) -> dict[str, Any]:
    track_spotify_id = payload.get("track_spotify_id", room.current_track_spotify_id or "")
    position_ms = int(payload.get("position_ms", 0))
    is_playing = bool(payload.get("is_playing", event in {"play", "track_change", "heartbeat"}))

    if event == "track_change":
        position_ms = 0

    return {
        "track_spotify_id": track_spotify_id,
        "track_title": payload.get("track_title", ""),
        "track_artist": payload.get("track_artist", ""),
        "track_cover_url": payload.get("track_cover_url", ""),
        "position_ms": position_ms,
        "is_playing": is_playing,
        "updated_at": time.time(),
        "host_id": host_id,
    }


@router.post(
    "/rooms/create",
    status_code=201,
    summary="Create listening room",
    description="Creates a listening room for the host, closes any existing active host room, and returns WebSocket connection details.",
)
async def create_room(
    body: CreateRoomRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.max_guests > 20:
        raise HTTPException(status_code=400, detail="max_guests must be <= 20")

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
        title=(body.name or DEFAULT_ROOM_NAME).strip() or DEFAULT_ROOM_NAME,
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

    ws_token = create_ws_token(current_user.id, room.id, expires_in_seconds=24 * 60 * 60)
    return {
        "room_id": room.id,
        "invite_code": _invite_code(room.id),
        "ws_token": ws_token,
        "ws_url": _ws_url(room.id, ws_token),
    }


@router.get(
    "/rooms/active",
    summary="List active rooms",
    description="Returns active listening rooms visible to the current user with host information, participant counts, participants, and current track state.",
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
                    ListeningRoom.id.in_(
                        select(RoomParticipant.room_id).where(
                            RoomParticipant.user_id == current_user.id,
                            RoomParticipant.left_at.is_(None),
                        )
                    ),
                ),
            )
            .order_by(ListeningRoom.created_at.desc())
            .limit(limit)
        )
    ).all()

    rooms: list[dict[str, Any]] = []
    for room, host in rows:
        participant_count = await _connected_participant_count(db, room.id)
        participant_user_ids = await _participant_user_ids(db, room.id)
        current_track = await _load_room_state(request.app.state.redis, room.id)
        rooms.append(
            {
                "room_id": room.id,
                "name": room.title,
                "is_public": room.is_public,
                "is_active": room.is_active,
                "host": {
                    "id": host.id,
                    "username": host.username,
                    "first_name": host.first_name,
                    "avatar_url": host.avatar_url,
                },
                "participant_count": participant_count,
                "participant_user_ids": participant_user_ids,
                "current_track": {
                    "track_spotify_id": current_track.get("track_spotify_id"),
                    "track_title": current_track.get("track_title"),
                    "track_artist": current_track.get("track_artist"),
                    "track_cover_url": current_track.get("track_cover_url"),
                    "position_ms": current_track.get("position_ms"),
                    "is_playing": current_track.get("is_playing"),
                }
                if current_track
                else None,
            }
        )

    return {"rooms": rooms}


@router.get(
    "/rooms/{room_id}",
    summary="Get room details",
    description="Returns details for an active listening room, including host info, invite code, and current playback state.",
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
    participant_count = await _connected_participant_count(db, room.id)
    current_track = await _load_room_state(request.app.state.redis, room.id)
    return {
        "room_id": room.id,
        "name": room.title,
        "is_public": room.is_public,
        "is_active": room.is_active,
        "max_guests": room.max_guests,
        "invite_code": _invite_code(room.id),
        "participant_count": participant_count,
        "host": {
            "id": host.id if host else room.host_id,
            "username": host.username if host else None,
            "first_name": host.first_name if host else None,
            "avatar_url": host.avatar_url if host else None,
        },
        "current_track": current_track or None,
    }


@router.post(
    "/rooms/{room_id}/join-request",
    status_code=202,
    summary="Request room join",
    description="Creates a pending join request for a listening room, stores it in Redis, and notifies the host.",
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
        raise HTTPException(status_code=400, detail="Already in room")

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
    if room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not host")

    request_key = _request_key(room_id, body.user_id)
    pending_request = await request.app.state.redis.get(request_key)
    if not pending_request:
        raise HTTPException(status_code=404, detail="Pending request not found")

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
    if room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not host")

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
    body: RoomMessageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    message = {
        "sender_id": current_user.id,
        "display_name": _display_name(current_user),
        "avatar_url": current_user.avatar_url or "",
        "text": body.text.strip(),
        "sent_at": datetime.utcnow().isoformat() + "Z",
        "type": "text",
    }
    firebase_svc.write_room_message(room_id, message)
    return {"ok": True}


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
    messages = firebase_svc.get_room_messages(room_id, limit=limit)
    return {"messages": messages}


QUEUE_TTL = 3600


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
    raw = await request.app.state.redis.get(f"room:{room_id}:queue")
    queue = json.loads(raw) if raw else []
    return {"queue": queue}


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
    raw = await request.app.state.redis.get(f"room:{room_id}:queue")
    queue = json.loads(raw) if raw else []
    queue.append({
        "track_id": body.track_id,
        "title": body.title,
        "artist": body.artist,
        "cover_url": body.cover_url,
        "duration_ms": body.duration_ms,
        "added_by": _display_name(current_user),
        "added_at": datetime.utcnow().isoformat() + "Z",
    })
    await request.app.state.redis.setex(f"room:{room_id}:queue", QUEUE_TTL, json.dumps(queue))
    return {"ok": True, "queue_length": len(queue)}


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
    if room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only host can remove from queue")
    raw = await request.app.state.redis.get(f"room:{room_id}:queue")
    queue = json.loads(raw) if raw else []
    if 0 <= track_index < len(queue):
        queue.pop(track_index)
    await request.app.state.redis.setex(f"room:{room_id}:queue", QUEUE_TTL, json.dumps(queue))
    return {"ok": True}


@router.post(
    "/rooms/{room_id}/close",
    summary="Close room",
    description="Closes an active listening room owned by the current host and broadcasts a room-closed event.",
)
async def close_room(
    room_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await db.get(ListeningRoom, room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    if room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not host")

    room.is_active = False
    room.closed_at = datetime.utcnow()
    await db.commit()
    await manager.broadcast(room_id, {"event": "room_closed"})
    return {"message": "Room closed"}


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

            if event in {"play", "pause", "seek", "track_change", "heartbeat"} and participant.role == RoomParticipantRole.host:
                state = _build_state(event, data, room, user_id)
                await _save_room_state(redis, room_id, state)
                room.current_track_spotify_id = state.get("track_spotify_id") or None
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
        participant = await db.scalar(
            select(RoomParticipant).where(
                RoomParticipant.room_id == room_id,
                RoomParticipant.user_id == user_id,
            )
        )
        if participant:
            participant.status = RoomParticipantStatus.disconnected
            participant.left_at = datetime.utcnow()

        room = await db.get(ListeningRoom, room_id)
        if room and room.host_id == user_id:
            room.is_active = False
            room.closed_at = datetime.utcnow()
            await db.commit()
            await manager.broadcast(room_id, {"event": "room_closed"})
        else:
            await db.commit()
            await manager.broadcast(room_id, {"event": "guest_left", "user_id": user_id})
