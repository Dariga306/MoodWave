from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_verified_user
from app.models.chat import Chat
from app.models.social import Match
from app.models.user import User
from app.services import firebase as firebase_svc
from app.services import firebase_service
from app.services.security import are_friends, users_are_blocked

router = APIRouter()

VALID_TRACK_PHRASES = {
    "Слушай это прямо сейчас",
    "Напомнило о тебе",
    "Это точно про нас",
    "Для такой погоды",
    "Ты обязана это услышать",
    "Почему это так больно",
}
VALID_REACTION_EMOJIS = {"❤️", "🔥", "😭", "🎯", "⚡", "💀", "🧐"}


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


class ReactRequest(BaseModel):
    message_id: Optional[str] = Field(default=None, min_length=1)
    emoji: str = Field(min_length=1, max_length=8)


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


def _preview_for_message(last_msg: dict) -> tuple[str | None, str | None]:
    message_type = last_msg.get("type", "text")
    if message_type == "text":
        return (last_msg.get("text") or "")[:60], message_type
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


async def _send_payload(
    *,
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

    await firebase_svc.send_push_notification(
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
    current_user: User = Depends(require_verified_user),
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
    current_user: User = Depends(require_verified_user),
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
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
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
    return response


@router.post(
    "/direct/{user_id}/start",
    summary="Start direct chat",
    description="Finds or creates a direct chat thread with another user and returns its metadata.",
)
async def start_direct_chat(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    chat, partner = await _get_or_create_direct_chat(user_id, current_user, db)
    return {
        "chat_id": chat.id,
        "chat_kind": "direct",
        "match_id": chat.match_id,
        "firebase_chat_id": chat.firebase_chat_id,
        "partner": {
            "id": partner.id,
            "username": partner.username,
            "display_name": partner.display_name,
            "first_name": partner.first_name,
            "avatar_url": partner.avatar_url,
            "city": partner.city,
        },
    }


@router.post(
    "/{match_id}/send-track",
    summary="Send track in chat",
    description="Sends a track message through Firebase for a match chat and triggers a push notification to the recipient.",
)
async def send_track(
    match_id: int,
    body: SendTrackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    if body.phrase and body.phrase not in VALID_TRACK_PHRASES:
        raise HTTPException(status_code=400, detail="Invalid track phrase")

    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")

    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
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
    body: SendTrackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
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
    body: SendAlbumRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
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
    body: SendAlbumRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    return await _send_payload(
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
    body: SendPlaylistRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
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
    body: SendPlaylistRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    return await _send_payload(
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
    body: SendImageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    match = await _get_match(match_id, current_user, db)
    partner = await _get_partner(match, current_user, db)
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    chat = await _get_or_create_chat(match, db)
    return await _send_payload(
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
    body: SendImageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    chat = await _get_chat_by_id(chat_id, current_user, db)
    partner = await db.get(User, _chat_partner_id(chat, current_user.id))
    if not partner:
        raise HTTPException(status_code=404, detail="Chat partner not found")
    if await users_are_blocked(db, current_user.id, partner.id):
        raise HTTPException(status_code=403, detail="User is blocked")
    return await _send_payload(
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
    body: SendTextRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
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

    await firebase_svc.send_push_notification(
        token=partner.fcm_token,
        title="New message",
        body=f"💬 {_sender_name(current_user)}: {body.text[:30]}",
        data={"event": "new_message", "match_id": match.id, "message_id": message_id},
    )
    return {"message_id": message_id, "sent_at": sent_at}


@router.post(
    "/thread/{chat_id}/send-text",
    summary="Send text in direct chat",
    description="Sends a text message through Firebase for a direct chat and triggers a push notification to the recipient.",
)
async def send_text_to_thread(
    chat_id: int,
    body: SendTextRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
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

    await firebase_svc.send_push_notification(
        token=partner.fcm_token,
        title="New message",
        body=f"💬 {_sender_name(current_user)}: {body.text[:30]}",
        data={"event": "new_message", "chat_id": chat.id, "message_id": message_id},
    )
    return {"message_id": message_id, "sent_at": sent_at}


@router.post(
    "/{match_id}/react",
    summary="React to chat message",
    description="Adds an emoji reaction to a Firebase chat message and notifies the original sender when appropriate.",
)
async def react(
    match_id: int,
    body: ReactRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    if body.emoji not in VALID_REACTION_EMOJIS:
        raise HTTPException(status_code=400, detail="Invalid reaction emoji")
    if not body.message_id:
        raise HTTPException(status_code=400, detail="message_id is required")

    match = await _get_match(match_id, current_user, db)
    chat = await _get_or_create_chat(match, db)
    ok = firebase_service.update_reaction(chat.firebase_chat_id or "", body.message_id, body.emoji, current_user.id)
    if not ok:
        raise HTTPException(status_code=503, detail="Unable to save reaction")

    message = firebase_service.get_message(chat.firebase_chat_id or "", body.message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")

    sender_id = message.get("sender_id")
    if sender_id:
        original_sender = await db.get(User, int(sender_id))
        if original_sender and original_sender.id != current_user.id:
            await firebase_svc.send_push_notification(
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
    current_user: User = Depends(require_verified_user),
):
    if body.emoji not in VALID_REACTION_EMOJIS:
        raise HTTPException(status_code=400, detail="Invalid reaction emoji")
    if not body.message_id:
        raise HTTPException(status_code=400, detail="message_id is required")

    chat = await _get_chat_by_id(chat_id, current_user, db)
    ok = firebase_service.update_reaction(chat.firebase_chat_id or "", body.message_id, body.emoji, current_user.id)
    if not ok:
        raise HTTPException(status_code=503, detail="Unable to save reaction")

    message = firebase_service.get_message(chat.firebase_chat_id or "", body.message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")

    sender_id = message.get("sender_id")
    if sender_id:
        original_sender = await db.get(User, int(sender_id))
        if original_sender and original_sender.id != current_user.id:
            await firebase_svc.send_push_notification(
                token=original_sender.fcm_token,
                title="New reaction",
                body=f"Someone reacted {body.emoji} to your track",
                data={"event": "track_reaction", "chat_id": chat.id, "message_id": body.message_id},
            )
    return {"message": "reaction added"}
