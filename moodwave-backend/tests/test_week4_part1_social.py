import asyncio
import time
from typing import Any

import httpx
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.user import TasteVector, User
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
            city="Astana",
            is_active=True,
            is_verified=True,
            is_public=True,
            show_activity=True,
            fcm_token="token-user-1",
        )
        user2 = User(
            email=f"{prefix}2@example.com",
            username=f"{prefix}user2",
            hashed_password=hash_password("password123"),
            first_name="Daniyar",
            city="Astana",
            is_active=True,
            is_verified=True,
            is_public=True,
            show_activity=True,
            fcm_token="token-user-2",
        )
        user3 = User(
            email=f"{prefix}3@example.com",
            username=f"{prefix}user3",
            hashed_password=hash_password("password123"),
            first_name="Aruzhan",
            city="Astana",
            is_active=True,
            is_verified=True,
            is_public=True,
            show_activity=True,
            fcm_token="token-user-3",
        )
        session.add_all([user1, user2, user3])
        await session.flush()

        vector = {"genre:rock": 1.0, "genre:indie_rock": 0.9, "mood_late_night": 0.8}
        session.add_all(
            [
                TasteVector(user_id=user1.id, vector=vector),
                TasteVector(user_id=user3.id, vector=vector),
            ]
        )

        await session.commit()

        return {
            "user1_id": user1.id,
            "user2_id": user2.id,
            "user3_id": user3.id,
            "user1_token": create_access_token(user1.id),
            "user2_token": create_access_token(user2.id),
            "user3_token": create_access_token(user3.id),
        }


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def main() -> None:
    prefix = f"week4social{int(time.time())}_"
    seeded = await _seed(prefix)

    try:
        async with httpx.AsyncClient(base_url="http://127.0.0.1:8000", timeout=30.0) as client:
            user1_headers = _auth_headers(seeded["user1_token"])
            user2_headers = _auth_headers(seeded["user2_token"])

            # Warm /matches and verify user3 would have been visible before blocking.
            response = await client.get("/matches", headers=user1_headers)
            assert response.status_code == 200, response.text
            match_candidates = response.json()["candidates"]
            assert any(candidate["user_id"] == seeded["user3_id"] for candidate in match_candidates), match_candidates

            response = await client.post(
                f"/friends/{seeded['user2_id']}/request",
                headers=user1_headers,
            )
            assert response.status_code == 200, response.text
            assert response.json()["status"] == "pending", response.json()

            response = await client.post(
                f"/friends/{seeded['user2_id']}/request",
                headers=user1_headers,
            )
            assert response.status_code == 400, response.text
            assert response.json()["detail"] == "Request already sent", response.json()

            response = await client.post(
                f"/friends/{seeded['user1_id']}/accept",
                headers=user2_headers,
            )
            assert response.status_code == 200, response.text
            assert response.json()["status"] == "accepted", response.json()

            response = await client.get("/friends", headers=user1_headers)
            assert response.status_code == 200, response.text
            friends = response.json()["friends"]
            assert any(friend["id"] == seeded["user2_id"] for friend in friends), friends

            response = await client.post(
                f"/users/{seeded['user3_id']}/block",
                headers=user1_headers,
            )
            assert response.status_code == 200, response.text
            assert response.json()["message"] == "User blocked", response.json()

            response = await client.get("/matches", headers=user1_headers)
            assert response.status_code == 200, response.text
            match_candidates = response.json()["candidates"]
            assert all(candidate["user_id"] != seeded["user3_id"] for candidate in match_candidates), match_candidates

            response = await client.get("/users/search", headers=user1_headers, params={"q": "user3"})
            assert response.status_code == 200, response.text
            users = response.json()["users"]
            assert all(user["id"] != seeded["user3_id"] for user in users), users

            response = await client.delete(
                f"/friends/{seeded['user2_id']}",
                headers=user1_headers,
            )
            assert response.status_code == 200, response.text
            assert response.json()["message"] == "Friend removed", response.json()

            response = await client.get("/friends", headers=user1_headers)
            assert response.status_code == 200, response.text
            friends = response.json()["friends"]
            assert all(friend["id"] != seeded["user2_id"] for friend in friends), friends

            # Recreate the friendship for the activity test because Test 7 removes it.
            response = await client.post(
                f"/friends/{seeded['user2_id']}/request",
                headers=user1_headers,
            )
            assert response.status_code == 200, response.text
            response = await client.post(
                f"/friends/{seeded['user1_id']}/accept",
                headers=user2_headers,
            )
            assert response.status_code == 200, response.text

            response = await client.post(
                "/tracks/social-track-123/play",
                headers=user2_headers,
                json={
                    "completion_pct": 55,
                    "title": "Sweater Weather",
                    "artist": "The Neighbourhood",
                },
            )
            assert response.status_code == 200, response.text

            response = await client.get("/friends/activity", headers=user1_headers)
            assert response.status_code == 200, response.text
            body = response.json()
            activity = body.get("live", []) + body.get("recent", [])
            friend_entry = next((item for item in activity if item["id"] == seeded["user2_id"]), None)
            assert friend_entry is not None, activity
            assert friend_entry["now_playing"] is not None, friend_entry
            assert friend_entry["now_playing"]["track_id"] == "social-track-123", friend_entry
            assert friend_entry["now_playing"]["title"] == "Sweater Weather", friend_entry
            assert friend_entry["now_playing"]["artist"] == "The Neighbourhood", friend_entry
            assert friend_entry["now_playing"]["played_at"], friend_entry

        print("All 8 requested tests passed.")
    finally:
        await _cleanup(prefix)


if __name__ == "__main__":
    asyncio.run(main())
