import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

import firebase_admin
from firebase_admin import credentials, db, messaging

from app.config import settings

logger = logging.getLogger(__name__)
_FALLBACK_STORE = Path(__file__).resolve().parents[2] / "tmp" / "chat_fallback.json"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_fallback_store() -> dict[str, Any]:
    try:
        if not _FALLBACK_STORE.exists():
            return {"chats": {}}
        return json.loads(_FALLBACK_STORE.read_text(encoding="utf-8"))
    except Exception as e:
        logger.warning("Chat fallback read failed: %s", e)
        return {"chats": {}}


def _write_fallback_store(payload: dict[str, Any]) -> None:
    try:
        _FALLBACK_STORE.parent.mkdir(parents=True, exist_ok=True)
        _FALLBACK_STORE.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except Exception as e:
        logger.warning("Chat fallback write failed: %s", e)


def _fallback_chat(payload: dict[str, Any], firebase_chat_id: str) -> dict[str, Any]:
    chats = payload.setdefault("chats", {})
    return chats.setdefault(
        firebase_chat_id,
        {
            "members": {},
            "created_at": _now_iso(),
            "messages": {},
        },
    )


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
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message_key = uuid4().hex
        chat.setdefault("messages", {})[message_key] = dict(message)
        _write_fallback_store(payload)
        return message_key
    try:
        ref = db.reference(f"chats/{firebase_chat_id}/messages")
        new_ref = ref.push(message)
        return new_ref.key
    except Exception as e:
        logger.warning("Firebase write_message failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message_key = uuid4().hex
        chat.setdefault("messages", {})[message_key] = dict(message)
        _write_fallback_store(payload)
        return message_key


def update_reaction(firebase_chat_id: str, message_key: str, emoji: str, user_id: int) -> bool:
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message = chat.setdefault("messages", {}).get(message_key)
        if not isinstance(message, dict):
            return False
        reactions = message.setdefault("reactions", {})
        users = reactions.setdefault(emoji, [])
        if user_id not in users:
            users.append(user_id)
        _write_fallback_store(payload)
        return True
    try:
        ref = db.reference(f"chats/{firebase_chat_id}/messages/{message_key}/reactions/{emoji}")
        current = ref.get() or []
        if user_id not in current:
            current.append(user_id)
            ref.set(current)
        return True
    except Exception as e:
        logger.warning("Firebase update_reaction failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message = chat.setdefault("messages", {}).get(message_key)
        if not isinstance(message, dict):
            return False
        reactions = message.setdefault("reactions", {})
        users = reactions.setdefault(emoji, [])
        if user_id not in users:
            users.append(user_id)
        _write_fallback_store(payload)
        return True


def get_message(firebase_chat_id: str, message_key: str) -> dict[str, Any] | None:
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message = chat.setdefault("messages", {}).get(message_key)
        if not isinstance(message, dict):
            return None
        return {**message, "message_id": message_key}
    try:
        payload = db.reference(f"chats/{firebase_chat_id}/messages/{message_key}").get()
        if not payload:
            return None
        payload["message_id"] = message_key
        return payload
    except Exception as e:
        logger.warning("Firebase get_message failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message = chat.setdefault("messages", {}).get(message_key)
        if not isinstance(message, dict):
            return None
        return {**message, "message_id": message_key}


def get_messages(firebase_chat_id: str, limit: int = 50) -> list[dict[str, Any]]:
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        messages = [
            {**item, "message_id": key}
            for key, item in chat.setdefault("messages", {}).items()
            if isinstance(item, dict)
        ]
        messages.sort(key=lambda item: item.get("sent_at", ""))
        return messages[-limit:]
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
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        messages = [
            {**item, "message_id": key}
            for key, item in chat.setdefault("messages", {}).items()
            if isinstance(item, dict)
        ]
        messages.sort(key=lambda item: item.get("sent_at", ""))
        return messages[-limit:]


def get_last_message(firebase_chat_id: str) -> dict[str, Any] | None:
    messages = get_messages(firebase_chat_id, limit=1)
    return messages[-1] if messages else None


async def delete_message(firebase_chat_id: str, message_key: str) -> bool:
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        messages = chat.setdefault("messages", {})
        if message_key in messages:
            messages.pop(message_key, None)
            _write_fallback_store(payload)
        return True
    try:
        db.reference(f"chats/{firebase_chat_id}/messages/{message_key}").delete()
        return True
    except Exception as e:
        logger.warning("Firebase delete_message failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat.setdefault("messages", {}).pop(message_key, None)
        _write_fallback_store(payload)
        return True


def create_chat_node(firebase_chat_id: str, user_a_id: int, user_b_id: int) -> bool:
    return create_group_chat_node(firebase_chat_id, [user_a_id, user_b_id])


def create_group_chat_node(firebase_chat_id: str, member_ids: list[int]) -> bool:
    members = {str(member_id): True for member_id in member_ids}
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat["members"] = members
        chat.setdefault("created_at", _now_iso())
        _write_fallback_store(payload)
        return True
    try:
        db.reference(f"chats/{firebase_chat_id}").update(
            {
                "members": members,
                "created_at": _now_iso(),
            }
        )
        return True
    except Exception as e:
        logger.warning("Firebase create_chat_node failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat["members"] = members
        chat.setdefault("created_at", _now_iso())
        _write_fallback_store(payload)
        return True


_ROOMS_FALLBACK = Path(__file__).resolve().parents[2] / "tmp" / "rooms_fallback.json"


def _read_rooms_fallback() -> dict[str, Any]:
    try:
        if not _ROOMS_FALLBACK.exists():
            return {"rooms": {}}
        return json.loads(_ROOMS_FALLBACK.read_text(encoding="utf-8"))
    except Exception as e:
        logger.warning("Rooms fallback read failed: %s", e)
        return {"rooms": {}}


def _write_rooms_fallback(payload: dict[str, Any]) -> None:
    try:
        _ROOMS_FALLBACK.parent.mkdir(parents=True, exist_ok=True)
        _ROOMS_FALLBACK.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except Exception as e:
        logger.warning("Rooms fallback write failed: %s", e)


def write_room_message(room_id: int, message: dict[str, Any]) -> str | None:
    if not init_firebase():
        payload = _read_rooms_fallback()
        room = payload.setdefault("rooms", {}).setdefault(str(room_id), {"messages": {}})
        key = uuid4().hex
        room.setdefault("messages", {})[key] = dict(message)
        _write_rooms_fallback(payload)
        return key
    try:
        ref = db.reference(f"rooms/{room_id}/messages")
        new_ref = ref.push(message)
        return new_ref.key
    except Exception as e:
        logger.warning("Firebase write_room_message failed: %s", e)
        payload = _read_rooms_fallback()
        room = payload.setdefault("rooms", {}).setdefault(str(room_id), {"messages": {}})
        key = uuid4().hex
        room.setdefault("messages", {})[key] = dict(message)
        _write_rooms_fallback(payload)
        return key


def get_room_messages(room_id: int, limit: int = 50) -> list[dict[str, Any]]:
    if not init_firebase():
        payload = _read_rooms_fallback()
        room = payload.get("rooms", {}).get(str(room_id), {"messages": {}})
        messages = [
            {**item, "message_id": key}
            for key, item in room.get("messages", {}).items()
            if isinstance(item, dict)
        ]
        messages.sort(key=lambda item: item.get("sent_at", ""))
        return messages[-limit:]
    try:
        data = (
            db.reference(f"rooms/{room_id}/messages")
            .order_by_key()
            .limit_to_last(limit)
            .get()
        )
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
        logger.warning("Firebase get_room_messages failed: %s", e)
        return []


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
