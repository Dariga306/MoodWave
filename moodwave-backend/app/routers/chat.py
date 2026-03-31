from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, require_verified_user
from app.models.chat import Chat
from app.models.social import Match
from app.models.user import User
from app.services import firebase as firebase_svc
from app.services import firebase_service
from app.services.security import users_are_blocked

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
    if not chat or not chat.firebase_chat_id:
        return {"messages": []}
    messages = await firebase_svc.get_messages(chat.firebase_chat_id, limit=limit)
    return {"messages": messages}


@router.get(
    "",
    summary="List chats",
    description="Returns chat threads for the current user with partner information and Firebase chat identifiers.",
)
@router.get(
    "/",
    summary="List chats",
    description="Returns chat threads for the current user with partner information and Firebase chat identifiers.",
)
async def list_chats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_verified_user),
):
    rows = (
        await db.execute(
            select(Chat, Match, User)
            .join(Match, Match.id == Chat.match_id)
            .join(
                User,
                or_(
                    and_(Match.user_a_id == current_user.id, User.id == Match.user_b_id),
                    and_(Match.user_b_id == current_user.id, User.id == Match.user_a_id),
                ),
            )
            .where(or_(Match.user_a_id == current_user.id, Match.user_b_id == current_user.id))
            .order_by(Chat.created_at.desc())
        )
    ).all()

    response: list[dict] = []
    for chat, match, partner in rows:
        if await users_are_blocked(db, current_user.id, partner.id):
            continue
        response.append(
            {
                "chat_id": chat.id,
                "match_id": match.id,
                "firebase_chat_id": chat.firebase_chat_id,
                "created_at": chat.created_at.isoformat(),
                "partner": {
                    "id": partner.id,
                    "username": partner.username,
                    "display_name": partner.display_name,
                    "first_name": partner.first_name,
                    "avatar_url": partner.avatar_url,
                },
            }
        )
    return response


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
    sent_at = _now_iso()
    message_id = firebase_service.write_message(
        chat.firebase_chat_id or "",
        {
            "type": "track",
            "sender_id": current_user.id,
            "spotify_track_id": body.track_id,
            "track_title": body.title,
            "track_artist": body.artist,
            "track_cover_url": body.cover_url or "",
            "track_preview_url": body.preview_url or "",
            "phrase": body.phrase or "",
            "phrase_emoji": body.phrase_emoji or "",
            "reactions": {},
            "sent_at": sent_at,
        },
    )
    if not message_id:
        raise HTTPException(status_code=503, detail="Unable to send message")

    chat.last_message_at = datetime.utcnow()
    await db.commit()

    await firebase_svc.send_push_notification(
        token=partner.fcm_token,
        title="New track",
        body=f"🎵 {_sender_name(current_user)} sent you a track",
        data={"event": "new_message", "match_id": match.id, "message_id": message_id},
    )
    return {"message_id": message_id, "sent_at": sent_at}


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
