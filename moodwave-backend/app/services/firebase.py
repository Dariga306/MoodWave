from datetime import datetime, timezone
from typing import Optional

from app.services import firebase_service


def init_firebase() -> bool:
    return firebase_service.init_firebase()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def send_text_message(firebase_chat_id: str, sender_id: int, text: str) -> Optional[str]:
    return firebase_service.write_message(
        firebase_chat_id,
        {
            "type": "text",
            "sender_id": sender_id,
            "text": text[:100],
            "sent_at": _now_iso(),
        },
    )


async def send_track_message(
    firebase_chat_id: str,
    sender_id: int,
    spotify_track_id: str,
    track_title: str,
    track_artist: str,
    track_cover_url: Optional[str],
    phrase: str,
    phrase_emoji: str,
    track_preview_url: Optional[str] = None,
) -> Optional[str]:
    return firebase_service.write_message(
        firebase_chat_id,
        {
            "type": "track",
            "sender_id": sender_id,
            "spotify_track_id": spotify_track_id,
            "track_title": track_title,
            "track_artist": track_artist,
            "track_cover_url": track_cover_url or "",
            "track_preview_url": track_preview_url or "",
            "phrase": phrase,
            "phrase_emoji": phrase_emoji,
            "reactions": {},
            "sent_at": _now_iso(),
        },
    )


async def add_reaction(firebase_chat_id: str, message_key: str, user_id: int, emoji: str) -> bool:
    return firebase_service.update_reaction(firebase_chat_id, message_key, emoji, user_id)


async def create_chat_node(firebase_chat_id: str, user_a_id: int, user_b_id: int) -> bool:
    return firebase_service.create_chat_node(firebase_chat_id, user_a_id, user_b_id)


async def get_message(firebase_chat_id: str, message_key: str) -> Optional[dict]:
    return firebase_service.get_message(firebase_chat_id, message_key)


async def get_messages(firebase_chat_id: str, limit: int = 50) -> list[dict]:
    return firebase_service.get_messages(firebase_chat_id, limit=limit)


async def send_push_notification(
    token: Optional[str],
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    return firebase_service.send_fcm_push(token, title, body, data)


async def get_last_message(firebase_chat_id: str) -> Optional[dict]:
    return firebase_service.get_last_message(firebase_chat_id)
