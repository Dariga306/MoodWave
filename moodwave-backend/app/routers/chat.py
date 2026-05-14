from __future__ import annotations

import asyncio
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, Body, Depends, File, HTTPException, Request, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.chat import (
    Chat,
    GroupChat,
    GroupChatAvatarHistory,
    GroupChatMember,
    GroupChatRole,
)
from app.models.rooms import (
    ListeningRoom,
    RoomParticipant,
    RoomParticipantRole,
    RoomParticipantStatus,
)
from app.models.social import Match
from app.models.user import User
from app.services import firebase as firebase_svc
from app.services import firebase_service
from app.services.security import are_friends, users_are_blocked

UPLOADS_DIR = Path(__file__).resolve().parents[2] / "uploads"
GROUP_UPLOADS_DIR = UPLOADS_DIR / "groups"

router = APIRouter()

VALID_TRACK_PHRASES = {
    "Слушай это прямо сейчас",
    "Напомнило о тебе",
    "Это точно про нас",
    "Для такой погоды",
    "Ты обязана это услышать",
    "Почему это так больно",
}
VALID_REACTION_EMOJIS = {"❤️", "🔥", "😂", "🤯", "😍", "👀", "💀", "😢", "🎵", "👏"}


class SendTrackRequest(BaseModel):
    track_id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    artist: str = Field(min_length=1)
    cover_url: Optional[str] = None
    preview_url: Optional[str] = None
    phrase: Optional[str] = None
    phrase_emoji: Optional[str] = Field(default=None, max_length=8)
    note: Optional[str] = Field(default=None, max_length=240)


class SendAlbumRequest(BaseModel):
    album_id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    artist: str = Field(min_length=1)
    cover_url: Optional[str] = None
    note: Optional[str] = Field(default=None, max_length=240)


class SendPlaylistRequest(BaseModel):
    playlist_id: int
    title: str = Field(min_length=1)
    cover_url: Optional[str] = None
    track_count: int = 0
    note: Optional[str] = Field(default=None, max_length=240)


class SendImageRequest(BaseModel):
    image_data_url: str = Field(min_length=10)
    caption: Optional[str] = Field(default=None, max_length=240)


class SendTextRequest(BaseModel):
    text: str = Field(min_length=1)


class SendRoomInviteRequest(BaseModel):
    room_id: int
    invite_code: str = Field(min_length=1, max_length=32)
    room_title: str = Field(default="Live Room", max_length=255)
    room_description: Optional[str] = Field(default=None, max_length=500)
    room_background_url: Optional[str] = Field(default=None, max_length=2048)
    invite_role: str = Field(default="listener", max_length=32)
    is_public: bool = False


class ReactRequest(BaseModel):
    message_id: Optional[str] = Field(default=None, min_length=1)
    emoji: str = Field(min_length=1, max_length=8)


class CreateGroupChatRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    member_ids: list[int] = Field(default_factory=list)
    avatar_url: Optional[str] = None


class PinMessageRequest(BaseModel):
    message_id: str
    preview: Optional[str] = ""


class HideChatRequest(BaseModel):
    chat_key: str = Field(min_length=2, max_length=64)


def _hidden_chats_key(user_id: int) -> str:
    return f"hidden_chats:{user_id}"


def _chat_hidden_key_for_chat(chat: Chat) -> str:
    if chat.match_id is not None:
        return f"m:{chat.match_id}"
    return f"c:{chat.id}"


def _chat_hidden_key_for_group(group_id: int) -> str:
    return f"g:{group_id}"


async def _hidden_chat_keys(request: Request, user_id: int) -> set[str]:
    try:
        values = await request.app.state.redis.smembers(_hidden_chats_key(user_id))
    except Exception:
        return set()
    result: set[str] = set()
    for value in values or []:
        result.add(value.decode() if isinstance(value, bytes) else str(value))
    return result


async def _hide_chat_key(request: Request, user_id: int, key: str) -> None:
    try:
        await request.app.state.redis.sadd(_hidden_chats_key(user_id), key)
        await request.app.state.redis.expire(
            _hidden_chats_key(user_id),
            60 * 60 * 24 * 365,
        )
    except Exception:
        pass


async def _show_chat_key(request: Request, user_id: int, key: str) -> None:
    try:
        await request.app.state.redis.srem(_hidden_chats_key(user_id), key)
    except Exception:
        pass


class ForwardMessagesRequest(BaseModel):
    source_firebase_chat_id: str = Field(min_length=1)
    message_ids: list[str] = Field(min_length=1, max_length=20)
    target_kind: str = Field(pattern="^(match|thread|group)$")
    target_id: int


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sender_name(user: User) -> str:
    return user.display_name or user.first_name or user.username


async def _get_match(match_id: int, current_user: User, db: AsyncSession) -> Match:
    match = await db.get(Match, match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    if current_user.id not in {match.user_a_id, match.user_b_id}:
        raise HTTPException(status_code=403, detail="Access denied")
    return match


def _other_user_id(match: Match, current_user_id: int) -> int:
    return match.user_b_id if match.user_a_id == current_user_id else match.user_a_id


def _chat_partner_id(chat: Chat, current_user_id: int) -> int:
    return chat.user_b_id if chat.user_a_id == current_user_id else chat.user_a_id


async def _get_or_create_chat(match: Match, db: AsyncSession) -> Chat:
    chat = await db.scalar(select(Chat).where(Chat.match_id == match.id))
    if chat:
        return chat

    firebase_chat_id = f"chat_{min(match.user_a_id, match.user_b_id)}_{max(match.user_a_id, match.user_b_id)}"
    chat = Chat(
        match_id=match.id,
        user_a_id=min(match.user_a_id, match.user_b_id),
        user_b_id=max(match.user_a_id, match.user_b_id),
        firebase_chat_id=firebase_chat_id,
    )
    db.add(chat)
    await db.flush()
    await firebase_svc.create_chat_node(firebase_chat_id, chat.user_a_id, chat.user_b_id)
    return chat


async def _get_partner(match: Match, current_user: User, db: AsyncSession) -> User:
    partner_id = _other_user_id(match, current_user.id)
    partner = await db.get(User, partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    return partner


async def _get_chat_by_id(chat_id: int, current_user: User, db: AsyncSession) -> Chat:
    chat = await db.get(Chat, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")
    if current_user.id not in {chat.user_a_id, chat.user_b_id}:
        raise HTTPException(status_code=403, detail="Access denied")
    return chat


async def _get_group_chat_by_id(
    group_chat_id: int,
    current_user: User,
    db: AsyncSession,
) -> GroupChat:
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group chat not found")
    member = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == current_user.id,
        )
    )
    if not member:
        raise HTTPException(status_code=403, detail="Access denied")
    return group


async def _group_members_with_users(
    group_chat_id: int,
    db: AsyncSession,
) -> list[tuple[GroupChatMember, User]]:
    return (
        await db.execute(
            select(GroupChatMember, User)
            .join(User, User.id == GroupChatMember.user_id)
            .where(GroupChatMember.group_chat_id == group_chat_id)
            .order_by(GroupChatMember.joined_at.asc())
        )
    ).all()


async def _get_group_membership(
    group_chat_id: int,
    user_id: int,
    db: AsyncSession,
) -> Optional[GroupChatMember]:
    return await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == user_id,
        )
    )


def _can_manage_group(member: Optional[GroupChatMember]) -> bool:
    return bool(member and member.role in (GroupChatRole.owner, GroupChatRole.admin))


async def _record_group_avatar_history(
    *,
    group_chat_id: int,
    avatar_url: Optional[str],
    changed_by_user_id: int,
    db: AsyncSession,
) -> None:
    normalized = (avatar_url or "").strip()
    if not normalized:
        return
    latest = await db.scalar(
        select(GroupChatAvatarHistory)
        .where(GroupChatAvatarHistory.group_chat_id == group_chat_id)
        .order_by(GroupChatAvatarHistory.created_at.desc())
        .limit(1)
    )
    if latest and latest.avatar_url == normalized:
        return
    db.add(
        GroupChatAvatarHistory(
            group_chat_id=group_chat_id,
            avatar_url=normalized,
            changed_by_user_id=changed_by_user_id,
        )
    )


async def _serialize_group_avatar_history(
    group: GroupChat,
    db: AsyncSession,
) -> list[dict]:
    rows = (
        await db.execute(
            select(GroupChatAvatarHistory)
            .where(GroupChatAvatarHistory.group_chat_id == group.id)
            .order_by(GroupChatAvatarHistory.created_at.desc())
        )
    ).scalars().all()
    history: list[dict] = []
    seen: set[str] = set()
    current = (group.avatar_url or "").strip()
    if current:
        seen.add(current)
        history.append(
            {
                "avatar_url": current,
                "is_current": True,
                "created_at": group.updated_at.isoformat()
                if group.updated_at
                else group.created_at.isoformat(),
            }
        )
    for row in rows:
        avatar_url = (row.avatar_url or "").strip()
        if not avatar_url or avatar_url in seen:
            continue
        seen.add(avatar_url)
        history.append(
            {
                "avatar_url": avatar_url,
                "is_current": avatar_url == current,
                "created_at": row.created_at.isoformat(),
            }
        )
    return history


async def _assert_chat_access_by_firebase_id(
    firebase_chat_id: str,
    current_user: User,
    db: AsyncSession,
) -> None:
    chat = await db.scalar(select(Chat).where(Chat.firebase_chat_id == firebase_chat_id))
    if chat:
        if current_user.id not in {chat.user_a_id, chat.user_b_id}:
            raise HTTPException(status_code=403, detail="Access denied")
        return
    group = await db.scalar(
        select(GroupChat).where(
            GroupChat.firebase_chat_id == firebase_chat_id,
            GroupChat.is_active == True,
        )
    )
    if group:
        membership = await _get_group_membership(group.id, current_user.id, db)
        if not membership:
            raise HTTPException(status_code=403, detail="Access denied")
        return
    raise HTTPException(status_code=404, detail="Chat not found")


async def _get_or_create_direct_chat(
    target_user_id: int,
    current_user: User,
    db: AsyncSession,
) -> tuple[Chat, User]:
    if target_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot message yourself")

    target = await db.get(User, target_user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    if await users_are_blocked(db, current_user.id, target_user_id):
        raise HTTPException(status_code=403, detail="User is blocked")
    if not target.is_public:
        matched = await db.scalar(
            select(Match.id).where(
                or_(
                    and_(Match.user_a_id == current_user.id, Match.user_b_id == target_user_id),
                    and_(Match.user_a_id == target_user_id, Match.user_b_id == current_user.id),
                )
            )
        )
        are_connected = matched is not None or await are_friends(db, current_user.id, target_user_id)
        if not are_connected:
            existing_thread = await db.scalar(
                select(Chat.id).where(
                    Chat.match_id.is_(None),
                    or_(
                        and_(Chat.user_a_id == current_user.id, Chat.user_b_id == target_user_id),
                        and_(Chat.user_a_id == target_user_id, Chat.user_b_id == current_user.id),
                    ),
                )
            )
            # Private profiles can still be messaged if a prior direct thread exists.
            if not existing_thread:
                raise HTTPException(status_code=403, detail="User profile is private")

    chat = await db.scalar(
        select(Chat).where(
            Chat.match_id.is_(None),
            or_(
                and_(Chat.user_a_id == current_user.id, Chat.user_b_id == target_user_id),
                and_(Chat.user_a_id == target_user_id, Chat.user_b_id == current_user.id),
            ),
        )
    )
    if chat:
        return chat, target

    chat = Chat(
        match_id=None,
        user_a_id=min(current_user.id, target_user_id),
        user_b_id=max(current_user.id, target_user_id),
        firebase_chat_id=f"direct_{min(current_user.id, target_user_id)}_{max(current_user.id, target_user_id)}",
    )
    db.add(chat)
    await db.flush()
    await firebase_svc.create_chat_node(chat.firebase_chat_id or "", chat.user_a_id, chat.user_b_id)
    await db.commit()
    await db.refresh(chat)
    return chat, target


async def _messages_for_chat(chat: Chat, limit: int = 50) -> list[dict]:
    if not chat.firebase_chat_id:
        return []
    return await firebase_svc.get_messages(chat.firebase_chat_id, limit=limit)


async def _send_push_in_background(
    *,
    token: str | None,
    title: str,
    body: str,
    data: dict,
) -> None:
    try:
        await firebase_svc.send_push_notification(
            token=token,
            title=title,
            body=body,
            data=data,
        )
    except Exception:
        pass


def _dispatch_push_notification(
    *,
    token: str | None,
    title: str,
    body: str,
    data: dict,
) -> None:
    asyncio.create_task(
        _send_push_in_background(
            token=token,
            title=title,
            body=body,
            data=data,
        )
    )


def _preview_for_message(last_msg: dict) -> tuple[str | None, str | None]:
    message_type = last_msg.get("type", "text")
    if message_type == "text":
        return (last_msg.get("text") or "")[:60], message_type
    if message_type == "room_invite":
        title = last_msg.get("room_title") or "Live Room"
        return f"🎧 {title}", message_type
    if message_type == "track":
        title = last_msg.get("track_title", "")
        artist = last_msg.get("track_artist", "")
        return (
            f"🎵 {title} — {artist}" if artist else f"🎵 {title}",
            message_type,
        )
    if message_type == "album":
        artist = last_msg.get("album_artist", "")
        title = last_msg.get("album_title", "")
        return (
            f"💿 {artist} — {title}" if artist else f"💿 {title}",
            message_type,
        )
    if message_type == "playlist":
        return f"📀 {last_msg.get('playlist_title', 'Playlist')}", message_type
    if message_type == "image":
        caption = (last_msg.get("caption") or "").strip()
        return (f"🖼️ {caption}" if caption else "🖼️ Photo"), message_type
    return "New message", message_type


def _room_invite_payload(body: SendRoomInviteRequest) -> dict:
    return {
        "type": "room_invite",
        "room_id": body.room_id,
        "invite_code": body.invite_code,
        "room_title": body.room_title.strip() or "Live Room",
        "room_description": (body.room_description or "").strip(),
        "room_background_url": (body.room_background_url or "").strip(),
        "invite_role": (body.invite_role or "listener").strip(),
        "is_public": body.is_public,
        "reactions": {},
    }


async def _grant_room_invite_access(
    *,
    request: Request,
    db: AsyncSession,
    body: SendRoomInviteRequest,
    target_user_ids: list[int],
) -> None:
    room = await db.get(ListeningRoom, body.room_id)
    if not room or not room.is_active:
        return
    role = (body.invite_role or "listener").strip()
    changed = False
    for user_id in {int(uid) for uid in target_user_ids if int(uid) > 0}:
        participant = await db.scalar(
            select(RoomParticipant).where(
                RoomParticipant.room_id == body.room_id,
                RoomParticipant.user_id == user_id,
            )
        )
        if participant:
            if participant.status not in {
                RoomParticipantStatus.approved,
                RoomParticipantStatus.connected,
            }:
                participant.status = RoomParticipantStatus.approved
                participant.left_at = None
                changed = True
        else:
            db.add(
                RoomParticipant(
                    room_id=body.room_id,
                    user_id=user_id,
                    role=RoomParticipantRole.guest,
                    status=RoomParticipantStatus.approved,
                )
            )
            changed = True
        if role in {"co_host", "listener", "participant"}:
            try:
                await request.app.state.redis.setex(
                    f"room:{body.room_id}:role:{user_id}",
                    60 * 60 * 24 * 7,
                    role,
                )
            except Exception:
                pass
    if changed:
        await db.commit()


def _hide_forward_profile(user: User | None) -> bool:
    if not user:
        return True
    settings = getattr(user, "notif_settings_json", None) or {}
    return bool(settings.get("hide_forward_profile"))


async def _forward_payload(
    *,
    source_message: dict,
    db: AsyncSession,
) -> dict:
    original_sender_id = int(source_message.get("sender_id") or 0)
    original_sender = await db.get(User, original_sender_id) if original_sender_id else None
    hide_profile = _hide_forward_profile(original_sender)
    blocked = {
        "message_id",
        "sender_id",
        "sender_name",
        "sender_avatar_url",
        "sent_at",
        "reactions",
    }
    payload = {
        key: value
        for key, value in source_message.items()
        if key not in blocked and not key.startswith("_")
    }
    payload.update(
        {
            "forwarded": True,
            "forwarded_original_message_id": source_message.get("message_id", ""),
            "forwarded_from_user_id": None if hide_profile else original_sender_id,
            "forwarded_from_name": ""
            if hide_profile
            else (_sender_name(original_sender) if original_sender else ""),
            "forwarded_profile_hidden": hide_profile,
            "reactions": {},
        }
    )
    return payload


async def _send_payload(
    *,
    request: Request,
    chat: Chat,
    partner: User,
    current_user: User,
    payload: dict,
    db: AsyncSession,
    push_title: str,
    push_body: str,
    data: dict,
):
    sent_at = _now_iso()
    message_id = firebase_service.write_message(
        chat.firebase_chat_id or "",
        {
            **payload,
            "sender_id": current_user.id,
            "sent_at": sent_at,
        },
    )
    if not message_id:
        raise HTTPException(status_code=503, detail="Unable to send message")

    chat.last_message_at = datetime.utcnow()
    await db.commit()
    await _show_chat_key(request, current_user.id, _chat_hidden_key_for_chat(chat))
    await _show_chat_key(request, partner.id, _chat_hidden_key_for_chat(chat))

    _dispatch_push_notification(
        token=partner.fcm_token,
        title=push_title,
        body=push_body,
        data={**data, "message_id": message_id},
    )
    return {"message_id": message_id, "sent_at": sent_at}


@router.get(
    "/{match_id}/messages",
    summary="Get chat messages",
    description="Returns recent Firebase-backed messages for the chat associated with the specified match.",
)
async def get_messages(
    match_id: int,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = await _get_match(match_id, current_user, db)
    chat = await db.scalar(select(Chat).where(Chat.match_id == match.id))
    if not chat:
        return {"messages": []}
    return {"messages": await _messages_for_chat(chat, limit=limit)}


@router.get(
    "/thread/{chat_id}/messages",
    summary="Get direct chat messages",
    description="Returns recent Firebase-backed messages for a direct chat thread.",
)
async def get_thread_messages(
    chat_id: int,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    return {"messages": await _messages_for_chat(chat, limit=limit)}


@router.get(
    "",
    summary="List chats",
    description="Returns enriched chat threads: partner info, similarity %, last message preview and timestamp.",
)
@router.get(
    "/",
    summary="List chats",
    description="Returns enriched chat threads: partner info, similarity %, last message preview and timestamp.",
)
async def list_chats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        now = datetime.utcnow().isoformat() + "Z"
        await request.app.state.redis.setex(
            f"presence:{current_user.id}",
            90,
            json.dumps(
                {
                    "user_id": current_user.id,
                    "last_seen_at": now,
                }
            ),
        )
        await request.app.state.redis.set(f"last_seen:{current_user.id}", now)
    except Exception:
        pass
    hidden_keys = await _hidden_chat_keys(request, current_user.id)
    rows = (
        await db.execute(
            select(Chat, Match, User)
            .outerjoin(Match, Match.id == Chat.match_id)
            .join(
                User,
                or_(
                    and_(Chat.user_a_id == current_user.id, User.id == Chat.user_b_id),
                    and_(Chat.user_b_id == current_user.id, User.id == Chat.user_a_id),
                ),
            )
            .where(or_(Chat.user_a_id == current_user.id, Chat.user_b_id == current_user.id))
            .order_by(func.coalesce(Chat.last_message_at, Chat.created_at).desc())
        )
    ).all()

    response: list[dict] = []
    for chat, match, partner in rows:
        if _chat_hidden_key_for_chat(chat) in hidden_keys:
            continue
        if await users_are_blocked(db, current_user.id, partner.id):
            continue

        last_message_preview: Optional[str] = None
        last_message_type: Optional[str] = None
        if chat.firebase_chat_id:
            try:
                last_msg = firebase_service.get_last_message(chat.firebase_chat_id)
                if last_msg:
                    last_message_preview, last_message_type = _preview_for_message(last_msg)
            except Exception:
                pass

        response.append(
            {
                "chat_id": chat.id,
                "match_id": match.id if match else None,
                "chat_kind": "match" if match else "direct",
                "group_chat_id": None,
                "firebase_chat_id": chat.firebase_chat_id,
                "similarity_pct": match.similarity_pct if match else 0,
                "created_at": chat.created_at.isoformat(),
                "last_message_at": chat.last_message_at.isoformat() if chat.last_message_at else None,
                "last_message_preview": last_message_preview,
                "last_message_type": last_message_type,
                "partner": {
                    "id": partner.id,
                    "username": partner.username,
                    "display_name": partner.display_name,
                    "first_name": partner.first_name,
                    "avatar_url": partner.avatar_url,
                    "city": partner.city,
                },
            }
        )

    group_rows = (
        await db.execute(
            select(GroupChat)
            .join(
                GroupChatMember,
                GroupChatMember.group_chat_id == GroupChat.id,
            )
            .where(
                GroupChatMember.user_id == current_user.id,
                GroupChat.is_active == True,
            )
            .order_by(func.coalesce(GroupChat.last_message_at, GroupChat.created_at).desc())
        )
    ).scalars().all()

    for group in group_rows:
        if _chat_hidden_key_for_group(group.id) in hidden_keys:
            continue
        members = await _group_members_with_users(group.id, db)
        visible_members = [
            user
            for _, user in members
            if user.id != current_user.id
            and not await users_are_blocked(db, current_user.id, user.id)
        ]
        member_payloads = [
            {
                "id": user.id,
                "username": user.username,
                "display_name": user.display_name,
                "first_name": user.first_name,
                "avatar_url": user.avatar_url,
                "city": user.city,
            }
            for user in visible_members
        ]
        last_message_preview: Optional[str] = None
        last_message_type: Optional[str] = None
        if group.firebase_chat_id:
            try:
                last_msg = firebase_service.get_last_message(group.firebase_chat_id)
                if last_msg:
                    last_message_preview, last_message_type = _preview_for_message(last_msg)
            except Exception:
                pass

        response.append(
            {
                "chat_id": None,
                "match_id": None,
                "chat_kind": "group",
                "group_chat_id": group.id,
                "firebase_chat_id": group.firebase_chat_id,
                "similarity_pct": 0,
                "created_at": group.created_at.isoformat(),
                "updated_at": group.updated_at.isoformat()
                if group.updated_at
                else group.created_at.isoformat(),
                "last_message_at": group.last_message_at.isoformat()
                if group.last_message_at
                else None,
                "last_message_preview": last_message_preview,
                "last_message_type": last_message_type,
                "partner": {
                    "id": group.id,
                    "username": "",
                    "display_name": group.title,
                    "first_name": group.title,
                    "avatar_url": group.avatar_url,
                    "city": "",
                },
                "members": member_payloads,
                "member_count": len(members),
            }
        )

    response.sort(
        key=lambda item: item.get("last_message_at") or item.get("created_at") or "",
        reverse=True,
    )
    return response


@router.post(
    "/direct/{user_id}/start",
    summary="Start direct chat",
    description="Finds or creates a direct chat thread with another user and returns its metadata.",
)
async def start_direct_chat(
    user_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat, partner = await _get_or_create_direct_chat(user_id, current_user, db)
    # Unhide if previously hidden so the chat reappears in the list
    chat_key = _chat_hidden_key_for_chat(chat)
    await _show_chat_key(request, current_user.id, chat_key)
    return {
        "chat_id": chat.id,
        "chat_kind": "direct",
        "match_id": chat.match_id,
        "firebase_chat_id": chat.firebase_chat_id,
        "created_at": chat.created_at.isoformat(),
        "updated_at": chat.last_message_at.isoformat() if chat.last_message_at else chat.created_at.isoformat(),
        "last_message_at": chat.last_message_at.isoformat() if chat.last_message_at else None,
        "partner": {
            "id": partner.id,
            "username": partner.username,
            "display_name": partner.display_name,
            "first_name": partner.first_name,
            "avatar_url": partner.avatar_url,
            "city": partner.city,
        },
    }


@router.delete(
    "/hide",
    summary="Hide a chat for current user",
    description="Removes a chat from the current user's Social list without deleting messages for other participants.",
)
async def hide_chat(
    body: HideChatRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    key = body.chat_key.strip()
    try:
        prefix, raw_id = key.split(":", 1)
        target_id = int(raw_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid chat key")
    allowed = False
    if prefix == "g":
        allowed = await _get_group_membership(target_id, current_user.id, db) is not None
    elif prefix == "c":
        chat = await _get_chat_by_id(target_id, current_user, db)
        allowed = chat is not None
    elif prefix == "m":
        match = await _get_match(target_id, current_user, db)
        allowed = match is not None
    if not allowed:
        raise HTTPException(status_code=404, detail="Chat not found")
    await _hide_chat_key(request, current_user.id, key)
    return {"ok": True, "chat_key": key}


@router.delete(
    "/delete",
    summary="Delete a chat thread",
    description="Clears direct chat history and hides it from Social until a new message is sent. Group chats are only hidden for the current user.",
)
async def delete_chat_thread(
    body: HideChatRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    key = body.chat_key.strip()
    try:
        prefix, raw_id = key.split(":", 1)
        target_id = int(raw_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid chat key")

    if prefix == "g":
        allowed = await _get_group_membership(target_id, current_user.id, db) is not None
        if not allowed:
            raise HTTPException(status_code=404, detail="Chat not found")
        await _hide_chat_key(request, current_user.id, key)
        return {"ok": True, "chat_key": key, "mode": "hidden_only"}

    if prefix == "c":
        chat = await _get_chat_by_id(target_id, current_user, db)
    elif prefix == "m":
        match = await _get_match(target_id, current_user, db)
        chat = await _get_or_create_chat(match, db)
    else:
        raise HTTPException(status_code=404, detail="Chat not found")

    partner_id = _chat_partner_id(chat, current_user.id)
    firebase_chat_id = (chat.firebase_chat_id or "").strip()
    if firebase_chat_id:
        firebase_service.clear_chat(firebase_chat_id)
    chat.last_message_at = None
    await db.commit()

    hide_key = _chat_hidden_key_for_chat(chat)
    await _hide_chat_key(request, current_user.id, hide_key)
    await _hide_chat_key(request, partner_id, hide_key)
    return {"ok": True, "chat_key": hide_key, "mode": "cleared"}


async def _send_group_payload(
    *,
    request: Request,
    group: GroupChat,
    current_user: User,
    payload: dict,
    db: AsyncSession,
) -> dict[str, str]:
    sent_at = _now_iso()
    message_id = firebase_service.write_message(
        group.firebase_chat_id or "",
        {
            **payload,
            "sender_id": current_user.id,
            "sender_name": _sender_name(current_user),
            "sender_avatar_url": current_user.avatar_url,
            "sent_at": sent_at,
        },
    )
    if not message_id:
        raise HTTPException(status_code=503, detail="Unable to send message")
    group.last_message_at = datetime.utcnow()
    await db.commit()
    member_ids = (
        await db.scalars(
            select(GroupChatMember.user_id).where(
                GroupChatMember.group_chat_id == group.id,
            )
        )
    ).all()
    hidden_key = _chat_hidden_key_for_group(group.id)
    for member_id in member_ids:
        await _show_chat_key(request, int(member_id), hidden_key)
    return {"message_id": message_id, "sent_at": sent_at}


@router.post(
    "/groups",
    summary="Create group chat",
    description="Creates a regular group chat with selected members.",
)
async def create_group_chat(
    body: CreateGroupChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    title = body.title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="Title is required")

    member_ids = {member_id for member_id in body.member_ids if member_id != current_user.id}
    valid_members: list[User] = []
    for member_id in member_ids:
        user = await db.get(User, member_id)
        if not user:
            continue
        if await users_are_blocked(db, current_user.id, member_id):
            continue
        valid_members.append(user)

    firebase_chat_id = f"group_{current_user.id}_{int(datetime.utcnow().timestamp())}"
    group = GroupChat(
        owner_id=current_user.id,
        title=title,
        avatar_url=body.avatar_url,
        firebase_chat_id=firebase_chat_id,
        is_active=True,
    )
    db.add(group)
    await db.flush()

    db.add(
        GroupChatMember(
            group_chat_id=group.id,
            user_id=current_user.id,
            role=GroupChatRole.owner,
        )
    )
    for user in valid_members:
        db.add(
            GroupChatMember(
                group_chat_id=group.id,
                user_id=user.id,
                role=GroupChatRole.member,
            )
        )
    await _record_group_avatar_history(
        group_chat_id=group.id,
        avatar_url=group.avatar_url,
        changed_by_user_id=current_user.id,
        db=db,
    )
    await db.commit()
    await db.refresh(group)
    firebase_service.create_group_chat_node(
        firebase_chat_id,
        [current_user.id, *[user.id for user in valid_members]],
    )

    return {
        "group_chat_id": group.id,
        "chat_kind": "group",
        "title": group.title,
        "avatar_url": group.avatar_url,
        "firebase_chat_id": group.firebase_chat_id,
        "member_count": 1 + len(valid_members),
        "members": [
            {
                "id": current_user.id,
                "username": current_user.username,
                "display_name": current_user.display_name,
                "first_name": current_user.first_name,
                "avatar_url": current_user.avatar_url,
            },
            *[
                {
                    "id": user.id,
                    "username": user.username,
                    "display_name": user.display_name,
                    "first_name": user.first_name,
                    "avatar_url": user.avatar_url,
                }
                for user in valid_members
            ],
        ],
    }


@router.get(
    "/groups/{group_chat_id}",
    summary="Get group chat details",
)
async def get_group_chat_details(
    group_chat_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    members = await _group_members_with_users(group.id, db)
    return {
        "group_chat_id": group.id,
        "title": group.title,
        "avatar_url": group.avatar_url,
        "updated_at": group.updated_at.isoformat() if group.updated_at else None,
        "firebase_chat_id": group.firebase_chat_id,
        "member_count": len(members),
        "avatar_history": await _serialize_group_avatar_history(group, db),
        "members": [
            {
                "id": user.id,
                "username": user.username,
                "display_name": user.display_name,
                "first_name": user.first_name,
                "avatar_url": user.avatar_url,
                "role": member.role.value,
            }
            for member, user in members
        ],
    }


class UpdateGroupChatRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    avatar_url: Optional[str] = None


@router.patch(
    "/groups/{group_chat_id}",
    summary="Update group chat name or avatar (owner or admin)",
)
async def update_group_chat(
    group_chat_id: int,
    body: UpdateGroupChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group not found")
    my_membership = await _get_group_membership(group_chat_id, current_user.id, db)
    if not _can_manage_group(my_membership):
        raise HTTPException(status_code=403, detail="Only owner or admin can edit the group")
    changed = False
    if body.title is not None:
        title = body.title.strip()
        if not title:
            raise HTTPException(status_code=400, detail="Title is required")
        if group.title != title:
            group.title = title
            changed = True
    if body.avatar_url is not None:
        avatar_url = body.avatar_url.strip()
        next_avatar_url = avatar_url or None
        if group.avatar_url != next_avatar_url:
            group.avatar_url = next_avatar_url
            changed = True
            await _record_group_avatar_history(
                group_chat_id=group.id,
                avatar_url=next_avatar_url,
                changed_by_user_id=current_user.id,
                db=db,
            )
    if changed:
        group.updated_at = datetime.utcnow()
    await db.commit()
    return {
        "ok": True,
        "title": group.title,
        "avatar_url": group.avatar_url,
        "updated_at": group.updated_at.isoformat() if group.updated_at else None,
    }


@router.post(
    "/groups/{group_chat_id}/avatar",
    summary="Upload group chat avatar (owner or admin)",
)
async def upload_group_avatar(
    group_chat_id: int,
    request: Request,
    avatar: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group not found")
    my_membership = await _get_group_membership(group_chat_id, current_user.id, db)
    if not _can_manage_group(my_membership):
        raise HTTPException(status_code=403, detail="Only owner or admin can upload avatar")

    ext = os.path.splitext(avatar.filename or "")[1].lower()
    if not ext:
        ct = (avatar.content_type or "").lower()
        guessed = ct.split("/")[-1]
        ext = ".jpg" if guessed == "jpeg" else f".{guessed}"
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        raise HTTPException(status_code=400, detail="Unsupported image format")

    data = await avatar.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")

    GROUP_UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    file_name = f"group_{group_chat_id}_{int(datetime.utcnow().timestamp())}_{uuid4().hex[:10]}{ext}"
    (GROUP_UPLOADS_DIR / file_name).write_bytes(data)
    relative_path = f"groups/{file_name}"
    url = str(request.url_for("uploads", path=relative_path))
    group.avatar_url = url
    group.updated_at = datetime.utcnow()
    await _record_group_avatar_history(
        group_chat_id=group.id,
        avatar_url=url,
        changed_by_user_id=current_user.id,
        db=db,
    )
    await db.commit()
    return {
        "ok": True,
        "avatar_url": url,
        "updated_at": group.updated_at.isoformat() if group.updated_at else None,
    }


@router.get(
    "/groups/{group_chat_id}/avatars",
    summary="Get group avatar history",
)
async def get_group_avatar_history(
    group_chat_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    return {
        "avatars": await _serialize_group_avatar_history(group, db),
        "current_avatar_url": group.avatar_url,
    }


@router.delete(
    "/groups/{group_chat_id}/leave",
    summary="Leave group chat",
)
async def leave_group_chat(
    group_chat_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group not found")
    member = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == current_user.id,
        )
    )
    if not member:
        raise HTTPException(status_code=404, detail="Not a member")
    if group.owner_id == current_user.id:
        next_member = await db.scalar(
            select(GroupChatMember).where(
                GroupChatMember.group_chat_id == group_chat_id,
                GroupChatMember.user_id != current_user.id,
            ).order_by(GroupChatMember.joined_at.asc())
        )
        if next_member:
            group.owner_id = next_member.user_id
            next_member.role = GroupChatRole.owner
        else:
            group.is_active = False
    await db.delete(member)
    await db.commit()
    return {"ok": True}


class TransferOwnerRequest(BaseModel):
    new_owner_id: int


@router.delete(
    "/groups/{group_chat_id}/members/{user_id}",
    summary="Remove member from group chat (owner only)",
)
async def remove_group_member(
    group_chat_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group not found")
    my_membership = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == current_user.id,
        )
    )
    if not my_membership:
        raise HTTPException(status_code=403, detail="Not a member")
    if current_user.id == user_id:
        raise HTTPException(status_code=400, detail="Use leave endpoint to leave")
    member = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == user_id,
        )
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    # owner can remove anyone; admin can only remove regular members
    if my_membership.role == GroupChatRole.owner:
        pass
    elif my_membership.role == GroupChatRole.admin:
        if member.role in (GroupChatRole.owner, GroupChatRole.admin):
            raise HTTPException(status_code=403, detail="Admins can only remove regular members")
    else:
        raise HTTPException(status_code=403, detail="Only admins or owner can remove members")
    await db.delete(member)
    await db.commit()
    return {"ok": True}


@router.post(
    "/groups/{group_chat_id}/transfer-owner",
    summary="Transfer group chat ownership",
)
async def transfer_group_owner(
    group_chat_id: int,
    body: TransferOwnerRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group not found")
    if group.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the owner can transfer ownership")
    new_member = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == body.new_owner_id,
        )
    )
    if not new_member:
        raise HTTPException(status_code=404, detail="New owner is not a member")
    old_member = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == current_user.id,
        )
    )
    if old_member:
        old_member.role = GroupChatRole.member
    new_member.role = GroupChatRole.owner
    group.owner_id = body.new_owner_id
    await db.commit()
    return {"ok": True}


@router.post(
    "/groups/{group_chat_id}/members/{user_id}/make-admin",
    summary="Promote a member to admin (owner only)",
)
async def make_group_admin(
    group_chat_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group not found")
    if group.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the owner can promote members")
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Owner is already the highest role")
    member = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == user_id,
        )
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    member.role = GroupChatRole.admin
    await db.commit()
    return {"ok": True}


@router.delete(
    "/groups/{group_chat_id}/members/{user_id}/admin",
    summary="Revoke admin role (owner only)",
)
async def revoke_group_admin(
    group_chat_id: int,
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await db.get(GroupChat, group_chat_id)
    if not group or not group.is_active:
        raise HTTPException(status_code=404, detail="Group not found")
    if group.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the owner can revoke admin")
    member = await db.scalar(
        select(GroupChatMember).where(
            GroupChatMember.group_chat_id == group_chat_id,
            GroupChatMember.user_id == user_id,
        )
    )
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.role != GroupChatRole.admin:
        raise HTTPException(status_code=400, detail="Member is not an admin")
    member.role = GroupChatRole.member
    await db.commit()
    return {"ok": True}


@router.get(
    "/groups/{group_chat_id}/messages",
    summary="Get group chat messages",
)
async def get_group_chat_messages(
    group_chat_id: int,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    return {"messages": await _messages_for_chat(group, limit=limit)}


@router.post(
    "/groups/{group_chat_id}/send-text",
    summary="Send text in group chat",
)
async def send_text_to_group(
    group_chat_id: int,
    request: Request,
    body: SendTextRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    return await _send_group_payload(
        request=request,
        group=group,
        current_user=current_user,
        db=db,
        payload={
            "type": "text",
            "text": body.text,
        },
    )


@router.post(
    "/groups/{group_chat_id}/send-room-invite",
    summary="Send Live Room invite in group chat",
)
async def send_room_invite_to_group(
    group_chat_id: int,
    request: Request,
    body: SendRoomInviteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    members = (
        await db.scalars(
            select(GroupChatMember.user_id).where(
                GroupChatMember.group_chat_id == group_chat_id,
                GroupChatMember.user_id != current_user.id,
            )
        )
    ).all()
    await _grant_room_invite_access(
        request=request,
        db=db,
        body=body,
        target_user_ids=[int(user_id) for user_id in members],
    )
    return await _send_group_payload(
        request=request,
        group=group,
        current_user=current_user,
        db=db,
        payload=_room_invite_payload(body),
    )


@router.post(
    "/groups/{group_chat_id}/send-track",
    summary="Send track in group chat",
)
async def send_track_to_group(
    group_chat_id: int,
    request: Request,
    body: SendTrackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    return await _send_group_payload(
        request=request,
        group=group,
        current_user=current_user,
        db=db,
        payload={
            "type": "track",
            "spotify_track_id": body.track_id,
            "track_title": body.title,
            "track_artist": body.artist,
            "track_cover_url": body.cover_url,
            "track_preview_url": body.preview_url,
            "phrase": body.phrase,
            "phrase_emoji": body.phrase_emoji,
            "note": body.note,
        },
    )


@router.post(
    "/groups/{group_chat_id}/send-album",
    summary="Send album in group chat",
)
async def send_album_to_group(
    group_chat_id: int,
    request: Request,
    body: SendAlbumRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    return await _send_group_payload(
        request=request,
        group=group,
        current_user=current_user,
        db=db,
        payload={
            "type": "album",
            "album_id": body.album_id,
            "album_title": body.title,
            "album_artist": body.artist,
            "album_cover_url": body.cover_url,
            "note": body.note,
        },
    )


@router.post(
    "/groups/{group_chat_id}/send-playlist",
    summary="Send playlist in group chat",
)
async def send_playlist_to_group(
    group_chat_id: int,
    request: Request,
    body: SendPlaylistRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    return await _send_group_payload(
        request=request,
        group=group,
        current_user=current_user,
        db=db,
        payload={
            "type": "playlist",
            "playlist_id": body.playlist_id,
            "playlist_title": body.title,
            "playlist_cover_url": body.cover_url,
            "track_count": body.track_count,
            "note": body.note,
        },
    )


@router.post(
    "/groups/{group_chat_id}/send-image",
    summary="Send image in group chat",
)
async def send_image_to_group(
    group_chat_id: int,
    request: Request,
    body: SendImageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    return await _send_group_payload(
        request=request,
        group=group,
        current_user=current_user,
        db=db,
        payload={
            "type": "image",
            "image_data_url": body.image_data_url,
            "caption": body.caption,
        },
    )


@router.post(
    "/groups/{group_chat_id}/react",
    summary="React in group chat",
)
async def react_to_group_message(
    group_chat_id: int,
    body: ReactRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.emoji not in VALID_REACTION_EMOJIS:
        raise HTTPException(status_code=400, detail="Invalid reaction emoji")
    if not body.message_id:
        raise HTTPException(status_code=400, detail="message_id is required")
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    message = firebase_service.get_message(group.firebase_chat_id or "", body.message_id)
    ok = firebase_service.update_reaction(
        group.firebase_chat_id or "",
        body.message_id,
        body.emoji,
        current_user.id,
    )
    if not ok:
        raise HTTPException(status_code=503, detail="Unable to save reaction")
    return {"ok": True}


@router.delete(
    "/groups/{group_chat_id}/messages/{message_id}",
    summary="Delete group chat message",
)
async def delete_group_message(
    group_chat_id: int,
    message_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = await _get_group_chat_by_id(group_chat_id, current_user, db)
    msg = firebase_service.get_message(group.firebase_chat_id or "", message_id)
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    is_sender = int(msg.get("sender_id") or 0) == current_user.id
    my_membership = await _get_group_membership(group_chat_id, current_user.id, db)
    is_admin_or_owner = _can_manage_group(my_membership)
    if not is_sender and not is_admin_or_owner:
        raise HTTPException(
            status_code=403,
            detail="Only the sender, an admin, or the owner can delete this message",
        )
    await firebase_service.delete_message(group.firebase_chat_id or "", message_id)
    return {"ok": True}


@router.post(
    "/{match_id}/send-track",
    summary="Send track in chat",
    description="Sends a track message through Firebase for a match chat and triggers a push notification to the recipient.",
)
async def send_track(
    match_id: int,
    request: Request,
    body: SendTrackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.phrase and body.phrase not in VALID_TRACK_PHRASES:
        raise HTTPException(status_code=400, detail="Invalid track phrase")

    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")

    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "track",
            "spotify_track_id": body.track_id,
            "track_title": body.title,
            "track_artist": body.artist,
            "track_cover_url": body.cover_url or "",
            "track_preview_url": body.preview_url or "",
            "phrase": body.phrase or "",
            "phrase_emoji": body.phrase_emoji or "",
            "note": body.note or "",
            "reactions": {},
        },
        db=db,
        push_title="New track",
        push_body=f"🎵 {_sender_name(current_user)} sent you a track",
        data={"event": "new_message", "match_id": match.id},
    )
    


@router.post(
    "/thread/{chat_id}/send-track",
    summary="Send track in direct chat",
    description="Sends a track message through Firebase for a direct chat and triggers a push notification to the recipient.",
)
async def send_track_to_thread(
    chat_id: int,
    request: Request,
    body: SendTrackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.phrase and body.phrase not in VALID_TRACK_PHRASES:
        raise HTTPException(status_code=400, detail="Invalid track phrase")

    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")

    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "track",
            "spotify_track_id": body.track_id,
            "track_title": body.title,
            "track_artist": body.artist,
            "track_cover_url": body.cover_url or "",
            "track_preview_url": body.preview_url or "",
            "phrase": body.phrase or "",
            "phrase_emoji": body.phrase_emoji or "",
            "note": body.note or "",
            "reactions": {},
        },
        db=db,
        push_title="New track",
        push_body=f"🎵 {_sender_name(current_user)} sent you a track",
        data={"event": "new_message", "chat_id": chat.id},
    )


@router.post(
    "/{match_id}/send-album",
    summary="Send album in chat",
    description="Sends an album card in a match chat.",
)
async def send_album(
    match_id: int,
    request: Request,
    body: SendAlbumRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "album",
            "album_id": body.album_id,
            "album_title": body.title,
            "album_artist": body.artist,
            "album_cover_url": body.cover_url or "",
            "note": body.note or "",
        },
        db=db,
        push_title="New album",
        push_body=f"💿 {_sender_name(current_user)} shared an album",
        data={"event": "new_message", "match_id": match.id},
    )


@router.post(
    "/thread/{chat_id}/send-album",
    summary="Send album in direct chat",
    description="Sends an album card in a direct chat.",
)
async def send_album_to_thread(
    chat_id: int,
    request: Request,
    body: SendAlbumRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "album",
            "album_id": body.album_id,
            "album_title": body.title,
            "album_artist": body.artist,
            "album_cover_url": body.cover_url or "",
            "note": body.note or "",
        },
        db=db,
        push_title="New album",
        push_body=f"💿 {_sender_name(current_user)} shared an album",
        data={"event": "new_message", "chat_id": chat.id},
    )


@router.post(
    "/{match_id}/send-playlist",
    summary="Send playlist in chat",
    description="Sends a playlist card in a match chat.",
)
async def send_playlist(
    match_id: int,
    request: Request,
    body: SendPlaylistRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "playlist",
            "playlist_id": body.playlist_id,
            "playlist_title": body.title,
            "playlist_cover_url": body.cover_url or "",
            "playlist_track_count": body.track_count,
            "note": body.note or "",
        },
        db=db,
        push_title="New playlist",
        push_body=f"📀 {_sender_name(current_user)} shared a playlist",
        data={"event": "new_message", "match_id": match.id},
    )


@router.post(
    "/thread/{chat_id}/send-playlist",
    summary="Send playlist in direct chat",
    description="Sends a playlist card in a direct chat.",
)
async def send_playlist_to_thread(
    chat_id: int,
    request: Request,
    body: SendPlaylistRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "playlist",
            "playlist_id": body.playlist_id,
            "playlist_title": body.title,
            "playlist_cover_url": body.cover_url or "",
            "playlist_track_count": body.track_count,
            "note": body.note or "",
        },
        db=db,
        push_title="New playlist",
        push_body=f"📀 {_sender_name(current_user)} shared a playlist",
        data={"event": "new_message", "chat_id": chat.id},
    )


@router.post(
    "/{match_id}/send-image",
    summary="Send image in chat",
    description="Sends an image message in a match chat.",
)
async def send_image(
    match_id: int,
    request: Request,
    body: SendImageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "image",
            "image_data_url": body.image_data_url,
            "caption": body.caption or "",
        },
        db=db,
        push_title="New photo",
        push_body=f"🖼️ {_sender_name(current_user)} sent a photo",
        data={"event": "new_message", "match_id": match.id},
    )


@router.post(
    "/thread/{chat_id}/send-image",
    summary="Send image in direct chat",
    description="Sends an image message in a direct chat.",
)
async def send_image_to_thread(
    chat_id: int,
    request: Request,
    body: SendImageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload={
            "type": "image",
            "image_data_url": body.image_data_url,
            "caption": body.caption or "",
        },
        db=db,
        push_title="New photo",
        push_body=f"🖼️ {_sender_name(current_user)} sent a photo",
        data={"event": "new_message", "chat_id": chat.id},
    )


@router.post(
    "/{match_id}/send-text",
    summary="Send text in chat",
    description="Sends a text message through Firebase for a match chat and triggers a push notification to the recipient.",
)
async def send_text(
    match_id: int,
    request: Request,
    body: SendTextRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if len(body.text) > 100:
        raise HTTPException(status_code=400, detail="Text too long")

    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")

    chat = await _get_or_create_chat(match, db)
    sent_at = _now_iso()
    message_id = firebase_service.write_message(
        chat.firebase_chat_id or "",
        {
            "type": "text",
            "sender_id": current_user.id,
            "text": body.text,
            "sent_at": sent_at,
        },
    )
    if not message_id:
        raise HTTPException(status_code=503, detail="Unable to send message")

    chat.last_message_at = datetime.utcnow()
    await db.commit()
    await _show_chat_key(request, current_user.id, _chat_hidden_key_for_chat(chat))
    await _show_chat_key(request, partner.id, _chat_hidden_key_for_chat(chat))

    _dispatch_push_notification(
        token=partner.fcm_token,
        title="New message",
        body=f"💬 {_sender_name(current_user)}: {body.text[:30]}",
        data={"event": "new_message", "match_id": match.id, "message_id": message_id},
    )
    return {"message_id": message_id, "sent_at": sent_at}


@router.post(
    "/{match_id}/send-room-invite",
    summary="Send Live Room invite in chat",
)
async def send_room_invite(
    match_id: int,
    request: Request,
    body: SendRoomInviteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")

    chat = await _get_or_create_chat(match, db)
    await _grant_room_invite_access(
        request=request,
        db=db,
        body=body,
        target_user_ids=[partner.id],
    )
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload=_room_invite_payload(body),
        db=db,
        push_title="Live Room invite",
        push_body=f"🎧 {_sender_name(current_user)} invited you to listen together",
        data={"event": "new_message", "match_id": match.id, "room_id": body.room_id},
    )


@router.post(
    "/thread/{chat_id}/send-text",
    summary="Send text in direct chat",
    description="Sends a text message through Firebase for a direct chat and triggers a push notification to the recipient.",
)
async def send_text_to_thread(
    chat_id: int,
    request: Request,
    body: SendTextRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if len(body.text) > 100:
        raise HTTPException(status_code=400, detail="Text too long")

    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")

    sent_at = _now_iso()
    message_id = firebase_service.write_message(
        chat.firebase_chat_id or "",
        {
            "type": "text",
            "sender_id": current_user.id,
            "text": body.text,
            "sent_at": sent_at,
        },
    )
    if not message_id:
        raise HTTPException(status_code=503, detail="Unable to send message")

    chat.last_message_at = datetime.utcnow()
    await db.commit()
    await _show_chat_key(request, current_user.id, _chat_hidden_key_for_chat(chat))
    await _show_chat_key(request, partner.id, _chat_hidden_key_for_chat(chat))

    _dispatch_push_notification(
        token=partner.fcm_token,
        title="New message",
        body=f"💬 {_sender_name(current_user)}: {body.text[:30]}",
        data={"event": "new_message", "chat_id": chat.id, "message_id": message_id},
    )
    return {"message_id": message_id, "sent_at": sent_at}


@router.post(
    "/thread/{chat_id}/send-room-invite",
    summary="Send Live Room invite in direct chat",
)
async def send_room_invite_to_thread(
    chat_id: int,
    request: Request,
    body: SendRoomInviteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")

    await _grant_room_invite_access(
        request=request,
        db=db,
        body=body,
        target_user_ids=[partner.id],
    )
    return await _send_payload(
        request=request,
        chat=chat,
        partner=partner,
        current_user=current_user,
        payload=_room_invite_payload(body),
        db=db,
        push_title="Live Room invite",
        push_body=f"🎧 {_sender_name(current_user)} invited you to listen together",
        data={"event": "new_message", "chat_id": chat.id, "room_id": body.room_id},
    )


@router.post(
    "/{match_id}/react",
    summary="React to chat message",
    description="Adds an emoji reaction to a Firebase chat message and notifies the original sender when appropriate.",
)
async def react(
    match_id: int,
    body: ReactRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.emoji not in VALID_REACTION_EMOJIS:
        raise HTTPException(status_code=400, detail="Invalid reaction emoji")
    if not body.message_id:
        raise HTTPException(status_code=400, detail="message_id is required")

    match = await _get_match(match_id, current_user, db)
    chat = await _get_or_create_chat(match, db)
    message = firebase_service.get_message(chat.firebase_chat_id or "", body.message_id)
    ok = firebase_service.update_reaction(chat.firebase_chat_id or "", body.message_id, body.emoji, current_user.id)
    if not ok:
        raise HTTPException(status_code=503, detail="Unable to save reaction")

    sender_id = message.get("sender_id") if message else None
    if sender_id:
        original_sender = await db.get(User, int(sender_id))
        if original_sender and original_sender.id != current_user.id:
            _dispatch_push_notification(
                token=original_sender.fcm_token,
                title="New reaction",
                body=f"Someone reacted {body.emoji} to your track",
                data={"event": "track_reaction", "match_id": match.id, "message_id": body.message_id},
            )
    return {"message": "reaction added"}


@router.post(
    "/thread/{chat_id}/react",
    summary="React to direct chat message",
    description="Adds an emoji reaction to a Firebase direct-chat message and notifies the original sender when appropriate.",
)
async def react_to_thread(
    chat_id: int,
    body: ReactRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.emoji not in VALID_REACTION_EMOJIS:
        raise HTTPException(status_code=400, detail="Invalid reaction emoji")
    if not body.message_id:
        raise HTTPException(status_code=400, detail="message_id is required")

    chat = await _get_chat_by_id(chat_id, current_user, db)
    message = firebase_service.get_message(chat.firebase_chat_id or "", body.message_id)
    ok = firebase_service.update_reaction(chat.firebase_chat_id or "", body.message_id, body.emoji, current_user.id)
    if not ok:
        raise HTTPException(status_code=503, detail="Unable to save reaction")

    sender_id = message.get("sender_id") if message else None
    if sender_id:
        original_sender = await db.get(User, int(sender_id))
        if original_sender and original_sender.id != current_user.id:
            _dispatch_push_notification(
                token=original_sender.fcm_token,
                title="New reaction",
                body=f"Someone reacted {body.emoji} to your track",
                data={"event": "track_reaction", "chat_id": chat.id, "message_id": body.message_id},
            )
    return {"message": "reaction added"}


@router.delete(
    "/{match_id}/messages/{message_id}",
    status_code=200,
    summary="Delete a chat message",
)
async def delete_match_message(
    match_id: int,
    message_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = await _get_match(match_id, current_user, db)
    chat = await _get_or_create_chat(match, db)
    msg = firebase_service.get_message(chat.firebase_chat_id or "", message_id)
    if msg and str(msg.get("sender_id", "")) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Cannot delete another user's message")
    await firebase_service.delete_message(chat.firebase_chat_id or "", message_id)
    return {"ok": True}


@router.get("/pinned", summary="Get pinned messages for a chat")
async def get_pinned(
    firebase_chat_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _assert_chat_access_by_firebase_id(firebase_chat_id, current_user, db)
    pins = firebase_service.get_pinned_messages(firebase_chat_id)
    return {"pinned": pins}


@router.post("/pin", summary="Pin a message")
async def pin_message_endpoint(
    body: PinMessageRequest,
    firebase_chat_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _assert_chat_access_by_firebase_id(firebase_chat_id, current_user, db)
    ok = firebase_service.pin_message(
        firebase_chat_id, body.message_id, current_user.id, body.preview or ""
    )
    if not ok:
        raise HTTPException(status_code=503, detail="Unable to pin message")
    return {"ok": ok}


@router.delete("/pin", summary="Unpin a message")
async def unpin_message_endpoint(
    firebase_chat_id: str,
    message_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _assert_chat_access_by_firebase_id(firebase_chat_id, current_user, db)
    ok = firebase_service.unpin_message(firebase_chat_id, message_id)
    if not ok:
        raise HTTPException(status_code=503, detail="Unable to unpin message")
    return {"ok": ok}


@router.post("/unread-counts", summary="Get unread message counts for multiple chats")
async def get_unread_counts(
    payload: dict = Body(...),
    current_user: User = Depends(get_current_user),
):
    chats = payload.get("chats", [])
    result: dict[str, int] = {}
    for item in chats:
        fid = str(item.get("firebase_chat_id") or "")
        key = str(item.get("key") or fid)
        since = str(item.get("since") or "")
        if fid and since:
            result[key] = firebase_service.count_messages_since(fid, since, current_user.id)
    return result


@router.post("/forward", summary="Forward one or more chat messages")
async def forward_messages(
    body: ForwardMessagesRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _assert_chat_access_by_firebase_id(body.source_firebase_chat_id, current_user, db)
    messages: list[dict] = []
    for message_id in body.message_ids:
        msg = firebase_service.get_message(body.source_firebase_chat_id, message_id)
        if isinstance(msg, dict):
            messages.append(msg)
    if not messages:
        raise HTTPException(status_code=404, detail="Messages not found")

    sent: list[dict] = []
    if body.target_kind == "group":
        group = await _get_group_chat_by_id(body.target_id, current_user, db)
        for msg in messages:
            sent.append(
                await _send_group_payload(
                    request=request,
                    group=group,
                    current_user=current_user,
                    db=db,
                    payload=await _forward_payload(source_message=msg, db=db),
                )
            )
        return {"sent": sent}

    if body.target_kind == "thread":
        chat = await _get_chat_by_id(body.target_id, current_user, db)
        partner = await db.get(User, _chat_partner_id(chat, current_user.id))
        if not partner:
            raise HTTPException(status_code=404, detail="Chat partner not found")
        for msg in messages:
            sent.append(
                await _send_payload(
                    request=request,
                    chat=chat,
                    partner=partner,
                    current_user=current_user,
                    payload=await _forward_payload(source_message=msg, db=db),
                    db=db,
                    push_title="Forwarded message",
                    push_body=f"💬 {_sender_name(current_user)} forwarded a message",
                    data={"event": "new_message", "chat_id": chat.id},
                )
            )
        return {"sent": sent}

    match = await _get_match(body.target_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    chat = await _get_or_create_chat(match, db)
    for msg in messages:
        sent.append(
            await _send_payload(
                request=request,
                chat=chat,
                partner=partner,
                current_user=current_user,
                payload=await _forward_payload(source_message=msg, db=db),
                db=db,
                push_title="Forwarded message",
                push_body=f"💬 {_sender_name(current_user)} forwarded a message",
                data={"event": "new_message", "match_id": match.id},
            )
        )
    return {"sent": sent}


@router.delete(
    "/thread/{chat_id}/messages/{message_id}",
    status_code=200,
    summary="Delete a direct chat message",
)
async def delete_thread_message(
    chat_id: int,
    message_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    msg = firebase_service.get_message(chat.firebase_chat_id or "", message_id)
    if msg and str(msg.get("sender_id", "")) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Cannot delete another user's message")
    await firebase_service.delete_message(chat.firebase_chat_id or "", message_id)
    return {"ok": True}
