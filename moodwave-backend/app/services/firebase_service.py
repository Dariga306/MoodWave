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
    def toggle(reactions: dict[str, Any]) -> dict[str, Any]:
        had_same = False
        next_reactions: dict[str, Any] = {}
        for existing_emoji, raw_users in reactions.items():
            users = [
                int(item)
                for item in (raw_users or [])
                if str(item).isdigit() and int(item) != user_id
            ]
            if existing_emoji == emoji and len(users) != len(raw_users or []):
                had_same = True
            if users:
                next_reactions[existing_emoji] = users
        if not had_same:
            users = list(next_reactions.get(emoji) or [])
            if user_id not in users:
                users.append(user_id)
            next_reactions[emoji] = users
        return next_reactions

    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message = chat.setdefault("messages", {}).get(message_key)
        if not isinstance(message, dict):
            return False
        message["reactions"] = toggle(dict(message.get("reactions") or {}))
        _write_fallback_store(payload)
        return True
    try:
        ref = db.reference(f"chats/{firebase_chat_id}/messages/{message_key}/reactions")
        current = ref.get() or {}
        ref.set(toggle(dict(current) if isinstance(current, dict) else {}))
        return True
    except Exception as e:
        logger.warning("Firebase update_reaction failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        message = chat.setdefault("messages", {}).setdefault(message_key, {})
        message["reactions"] = toggle(dict(message.get("reactions") or {}))
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
        fallback = _read_fallback_store()
        fallback_chat = fallback.get("chats", {}).get(firebase_chat_id, {})
        fallback_messages = fallback_chat.get("messages", {})
        for message in messages:
            overlay = fallback_messages.get(message.get("message_id", ""))
            if isinstance(overlay, dict) and isinstance(overlay.get("reactions"), dict):
                merged = dict(message.get("reactions") or {})
                for emoji, users in overlay["reactions"].items():
                    existing = list(merged.get(emoji) or [])
                    for user_id in users or []:
                        if user_id not in existing:
                            existing.append(user_id)
                    merged[emoji] = existing
                message["reactions"] = merged
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


def count_messages_since(firebase_chat_id: str, since_iso: str, current_user_id: int | None = None) -> int:
    messages = get_messages(firebase_chat_id, limit=100)
    return sum(
        1
        for m in messages
        if m.get("sent_at", "") > since_iso
        and (current_user_id is None or int(m.get("sender_id") or 0) != current_user_id)
    )


def get_pinned_messages(firebase_chat_id: str) -> list[dict[str, Any]]:
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        pins = chat.get("pinned", {})
        return [{"message_id": k, **v} for k, v in pins.items() if isinstance(v, dict)]
    try:
        data = db.reference(f"chats/{firebase_chat_id}/pinned").get()
        pins = [{"message_id": k, **v} for k, v in (data or {}).items() if isinstance(v, dict)]
        fallback = _read_fallback_store()
        fallback_chat = fallback.get("chats", {}).get(firebase_chat_id, {})
        fallback_pins = fallback_chat.get("pinned", {})
        existing_ids = {pin.get("message_id") for pin in pins}
        for key, value in fallback_pins.items():
            if key not in existing_ids and isinstance(value, dict):
                pins.append({"message_id": key, **value})
        return pins
    except Exception as e:
        logger.warning("Firebase get_pinned_messages failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        pins = chat.get("pinned", {})
        return [{"message_id": k, **v} for k, v in pins.items() if isinstance(v, dict)]


def pin_message(firebase_chat_id: str, message_id: str, pinned_by: int, message_preview: str) -> bool:
    entry = {"pinned_by": pinned_by, "pinned_at": _now_iso(), "preview": message_preview}
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat.setdefault("pinned", {})[message_id] = entry
        _write_fallback_store(payload)
        return True
    try:
        db.reference(f"chats/{firebase_chat_id}/pinned/{message_id}").set(entry)
        return True
    except Exception as e:
        logger.warning("Firebase pin_message failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat.setdefault("pinned", {})[message_id] = entry
        _write_fallback_store(payload)
        return True


def unpin_message(firebase_chat_id: str, message_id: str) -> bool:
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat.get("pinned", {}).pop(message_id, None)
        _write_fallback_store(payload)
        return True
    try:
        db.reference(f"chats/{firebase_chat_id}/pinned/{message_id}").delete()
        return True
    except Exception as e:
        logger.warning("Firebase unpin_message failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat.get("pinned", {}).pop(message_id, None)
        _write_fallback_store(payload)
        return True


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


def clear_chat(firebase_chat_id: str) -> bool:
    if not init_firebase():
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat["messages"] = {}
        chat["pinned"] = {}
        _write_fallback_store(payload)
        return True
    try:
        db.reference(f"chats/{firebase_chat_id}/messages").delete()
        db.reference(f"chats/{firebase_chat_id}/pinned").delete()
        return True
    except Exception as e:
        logger.warning("Firebase clear_chat failed: %s", e)
        payload = _read_fallback_store()
        chat = _fallback_chat(payload, firebase_chat_id)
        chat["messages"] = {}
        chat["pinned"] = {}
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


def _room_messages_from_fallback(room_id: int, limit: int = 50) -> list[dict[str, Any]]:
    payload = _read_rooms_fallback()
    room = payload.get("rooms", {}).get(str(room_id), {"messages": {}})
    messages = [
        {**item, "message_id": key}
        for key, item in room.get("messages", {}).items()
        if isinstance(item, dict)
    ]
    messages.sort(key=lambda item: item.get("sent_at", ""))
    return messages[-limit:]


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
        return _room_messages_from_fallback(room_id, limit=limit)
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
        fallback_messages = _room_messages_from_fallback(room_id, limit=limit * 2)
        existing_ids = {message.get("message_id") for message in messages}
        for message in fallback_messages:
            if message.get("message_id") not in existing_ids:
                messages.append(message)
        messages.sort(key=lambda item: item.get("sent_at", ""))
        return messages[-limit:]
    except Exception as e:
        logger.warning("Firebase get_room_messages failed: %s", e)
        return _room_messages_from_fallback(room_id, limit=limit)


def get_room_message(room_id: int, message_id: str) -> dict[str, Any] | None:
    if not init_firebase():
        payload = _read_rooms_fallback()
        room = payload.get("rooms", {}).get(str(room_id), {"messages": {}})
        message = room.get("messages", {}).get(message_id)
        if not isinstance(message, dict):
            return None
        return {**message, "message_id": message_id}
    try:
        payload = db.reference(f"rooms/{room_id}/messages/{message_id}").get()
        if not isinstance(payload, dict):
            return None
        payload["message_id"] = message_id
        return payload
    except Exception as e:
        logger.warning("Firebase get_room_message failed: %s", e)
        payload = _read_rooms_fallback()
        room = payload.get("rooms", {}).get(str(room_id), {"messages": {}})
        message = room.get("messages", {}).get(message_id)
        if not isinstance(message, dict):
            return None
        return {**message, "message_id": message_id}


def update_room_message(room_id: int, message_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    clean_updates = {key: value for key, value in updates.items() if value is not None}
    if not clean_updates:
        return get_room_message(room_id, message_id)
    if not init_firebase():
        payload = _read_rooms_fallback()
        room = payload.setdefault("rooms", {}).setdefault(str(room_id), {"messages": {}})
        existing = room.setdefault("messages", {}).get(message_id)
        if not isinstance(existing, dict):
            return None
        existing.update(clean_updates)
        _write_rooms_fallback(payload)
        return {**existing, "message_id": message_id}
    try:
        ref = db.reference(f"rooms/{room_id}/messages/{message_id}")
        existing = ref.get()
        if not isinstance(existing, dict):
            return None
        ref.update(clean_updates)
        return {**existing, **clean_updates, "message_id": message_id}
    except Exception as e:
        logger.warning("Firebase update_room_message failed: %s", e)
        payload = _read_rooms_fallback()
        room = payload.setdefault("rooms", {}).setdefault(str(room_id), {"messages": {}})
        existing = room.setdefault("messages", {}).get(message_id)
        if not isinstance(existing, dict):
            return None
        existing.update(clean_updates)
        _write_rooms_fallback(payload)
        return {**existing, "message_id": message_id}


def delete_room_message(room_id: int, message_id: str) -> bool:
    if not init_firebase():
        payload = _read_rooms_fallback()
        room = payload.get("rooms", {}).get(str(room_id), {"messages": {}})
        room.get("messages", {}).pop(message_id, None)
        _write_rooms_fallback(payload)
        return True
    try:
        db.reference(f"rooms/{room_id}/messages/{message_id}").delete()
        return True
    except Exception as e:
        logger.warning("Firebase delete_room_message failed: %s", e)
        payload = _read_rooms_fallback()
        room = payload.get("rooms", {}).get(str(room_id), {"messages": {}})
        room.get("messages", {}).pop(message_id, None)
        _write_rooms_fallback(payload)
        return True


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
