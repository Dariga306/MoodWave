import asyncio
import time
from typing import Any

import httpx
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.chat import Chat
from app.models.social import Match
from app.models.user import User
from app.services.auth import create_access_token, hash_password


async def _cleanup(prefix: str) -> None:
    async with AsyncSessionLocal() as session:
        users = (
            await session.execute(select(User).where(User.username.like(f"{prefix}%")))
        ).scalars().all()
        for user in users:
            await session.delete(user)
        await session.commit()


async def _seed(prefix: str) -> dict[str, Any]:
    async with AsyncSessionLocal() as session:
        user1 = User(
            email=f"{prefix}1@example.com",
            username=f"{prefix}user1",
            hashed_password=hash_password("password123"),
            first_name="Amina",
            display_name="Amina Wave",
            is_active=True,
            is_verified=True,
            fcm_token="token-user-1",
        )
        user2 = User(
            email=f"{prefix}2@example.com",
            username=f"{prefix}user2",
            hashed_password=hash_password("password123"),
            first_name="Daniyar",
            display_name="Daniyar Beat",
            is_active=True,
            is_verified=True,
            fcm_token="token-user-2",
        )
        user3 = User(
            email=f"{prefix}3@example.com",
            username=f"{prefix}user3",
            hashed_password=hash_password("password123"),
            first_name="Unverified",
            is_active=True,
            is_verified=False,
            fcm_token="token-user-3",
        )
        session.add_all([user1, user2, user3])
        await session.flush()

        match = Match(
            user_a_id=min(user1.id, user2.id),
            user_b_id=max(user1.id, user2.id),
            similarity_pct=92,
        )
        session.add(match)
        await session.flush()

        chat = Chat(
            match_id=match.id,
            user_a_id=min(user1.id, user2.id),
            user_b_id=max(user1.id, user2.id),
            firebase_chat_id=f"{prefix}chat",
        )
        session.add(chat)
        await session.commit()

        return {
            "user1_token": create_access_token(user1.id),
            "user2_token": create_access_token(user2.id),
            "user3_token": create_access_token(user3.id),
            "match_id": match.id,
            "firebase_chat_id": chat.firebase_chat_id,
        }


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def main() -> None:
    prefix = f"week3chat{int(time.time())}_"
    seeded = await _seed(prefix)

    try:
        async with httpx.AsyncClient(base_url="http://127.0.0.1:8000", timeout=30.0) as client:
            user1_headers = _auth_headers(seeded["user1_token"])
            user2_headers = _auth_headers(seeded["user2_token"])
            user3_headers = _auth_headers(seeded["user3_token"])
            match_id = seeded["match_id"]

            response = await client.get("/chats", headers=user1_headers)
            assert response.status_code == 200, response.text
            chats = response.json()
            assert isinstance(chats, list), chats
            assert len(chats) == 1, chats
            assert chats[0]["match_id"] == match_id, chats
            assert chats[0]["firebase_chat_id"] == seeded["firebase_chat_id"], chats

            response = await client.post(
                f"/chats/{match_id}/send-text",
                headers=user1_headers,
                json={"text": "Hey! Your music taste is amazing 🎵"},
            )
            assert response.status_code == 200, response.text
            text_payload = response.json()
            assert text_payload["message_id"], text_payload
            assert text_payload["sent_at"], text_payload

            response = await client.post(
                f"/chats/{match_id}/send-text",
                headers=user1_headers,
                json={"text": "x" * 101},
            )
            assert response.status_code == 400, response.text
            assert response.json()["detail"] == "Text too long", response.json()

            response = await client.post(
                f"/chats/{match_id}/send-track",
                headers=user1_headers,
                json={
                    "track_id": "123",
                    "title": "Sweater Weather",
                    "artist": "The Neighbourhood",
                    "phrase": "Напомнило о тебе",
                    "phrase_emoji": "💭",
                },
            )
            assert response.status_code == 200, response.text
            track_payload = response.json()
            assert track_payload["message_id"], track_payload
            assert track_payload["sent_at"], track_payload

            response = await client.post(
                f"/chats/{match_id}/react",
                headers=user2_headers,
                json={"message_id": track_payload["message_id"], "emoji": "❤️"},
            )
            assert response.status_code == 200, response.text
            assert response.json()["message"] == "reaction added", response.json()

            response = await client.post(
                f"/chats/{match_id}/react",
                headers=user2_headers,
                json={"emoji": "🦋"},
            )
            assert response.status_code == 400, response.text
            assert response.json()["detail"] == "Invalid reaction emoji", response.json()

            response = await client.get("/chats", headers=user3_headers)
            assert response.status_code == 403, response.text
            detail = response.json()["detail"]
            assert detail["error"] == "email_not_verified", detail
            assert detail["message"] == "Please verify your email to use this feature", detail

        print("All 7 requested tests passed.")
    finally:
        await _cleanup(prefix)


if __name__ == "__main__":
    asyncio.run(main())
