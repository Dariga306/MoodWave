import logging
from datetime import datetime, timezone
from typing import Any

import firebase_admin
from firebase_admin import credentials, db, messaging

from app.config import settings

logger = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def init_firebase() -> bool:
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(
                cred,
                {"databaseURL": settings.FIREBASE_DATABASE_URL},
            )
        return True
    except Exception as e:
        logger.warning("Firebase init failed: %s", e)
        return False


def write_message(firebase_chat_id: str, message: dict[str, Any]) -> str | None:
    if not init_firebase():
        return None
    try:
        ref = db.reference(f"chats/{firebase_chat_id}/messages")
        new_ref = ref.push(message)
        return new_ref.key
    except Exception as e:
        logger.warning("Firebase write_message failed: %s", e)
        return None


def update_reaction(firebase_chat_id: str, message_key: str, emoji: str, user_id: int) -> bool:
    if not init_firebase():
        return False
    try:
        ref = db.reference(f"chats/{firebase_chat_id}/messages/{message_key}/reactions/{emoji}")
        current = ref.get() or []
        if user_id not in current:
            current.append(user_id)
            ref.set(current)
        return True
    except Exception as e:
        logger.warning("Firebase update_reaction failed: %s", e)
        return False


def get_message(firebase_chat_id: str, message_key: str) -> dict[str, Any] | None:
    if not init_firebase():
        return None
    try:
        payload = db.reference(f"chats/{firebase_chat_id}/messages/{message_key}").get()
        if not payload:
            return None
        payload["message_id"] = message_key
        return payload
    except Exception as e:
        logger.warning("Firebase get_message failed: %s", e)
        return None


def get_messages(firebase_chat_id: str, limit: int = 50) -> list[dict[str, Any]]:
    if not init_firebase():
        return []
    try:
        data = db.reference(f"chats/{firebase_chat_id}/messages").order_by_key().limit_to_last(limit).get()
        if not data:
            return []
        messages: list[dict[str, Any]] = []
        for key, payload in data.items():
            if not isinstance(payload, dict):
                continue
            payload["message_id"] = key
            messages.append(payload)
        messages.sort(key=lambda item: item.get("sent_at", ""))
        return messages
    except Exception as e:
        logger.warning("Firebase get_messages failed: %s", e)
        return []


def get_last_message(firebase_chat_id: str) -> dict[str, Any] | None:
    messages = get_messages(firebase_chat_id, limit=1)
    return messages[-1] if messages else None


def create_chat_node(firebase_chat_id: str, user_a_id: int, user_b_id: int) -> bool:
    if not init_firebase():
        return False
    try:
        db.reference(f"chats/{firebase_chat_id}").update(
            {
                "members": {str(user_a_id): True, str(user_b_id): True},
                "created_at": _now_iso(),
            }
        )
        return True
    except Exception as e:
        logger.warning("Firebase create_chat_node failed: %s", e)
        return False


def send_fcm_push(token: str | None, title: str, body: str, data: dict[str, Any] | None = None) -> bool:
    if not token:
        return False
    if not init_firebase():
        return False
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default"),
                )
            ),
        )
        messaging.send(message)
        return True
    except Exception as e:
        logger.warning("FCM push failed: %s", e)
        return False
