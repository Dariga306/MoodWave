import asyncio
import time
from datetime import date
from typing import Any

import httpx
import redis.asyncio as aioredis
from sqlalchemy import func, select

from app.config import settings
from app.database import AsyncSessionLocal
from app.models.chat import Chat
from app.models.music import ListeningHistory, Playlist, PlaylistTrack
from app.models.rooms import ListeningRoom, RoomParticipant, RoomParticipantRole, RoomParticipantStatus
from app.models.social import Block, Friend, FriendStatus, Match, MatchDecision, Report
from app.models.user import TasteVector, User, UserGenre, UserMood
from app.services.auth import hash_password


BASE_URL = "http://127.0.0.1:8000"


def _print_step(number: int, label: str, response: httpx.Response) -> Any:
    print(f"{number}. {label} -> {response.status_code}")
    return response


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def _cleanup(prefix: str) -> None:
    async with AsyncSessionLocal() as session:
        users = (
            await session.execute(
                select(User).where(
                    (User.username.like(f"{prefix}%")) | (User.email.like(f"{prefix}%"))
                )
            )
        ).scalars().all()
        for user in users:
            await session.delete(user)
        await session.commit()


async def _fetch_user(email: str) -> User | None:
    async with AsyncSessionLocal() as session:
        return await session.scalar(select(User).where(User.email == email))


async def _seed_delete_dependencies(prefix: str, main_user_id: int, playlist_id: int, room_id: int) -> dict[str, int]:
    async with AsyncSessionLocal() as session:
        helper_a = User(
            email=f"{prefix}helpera@example.com",
            username=f"{prefix}helpera",
            hashed_password=hash_password("password123"),
            first_name="HelperA",
            city="Astana",
            is_active=True,
            is_verified=True,
            is_public=True,
        )
        helper_b = User(
            email=f"{prefix}helperb@example.com",
            username=f"{prefix}helperb",
            hashed_password=hash_password("password123"),
            first_name="HelperB",
            city="Astana",
            is_active=True,
            is_verified=True,
            is_public=True,
        )
        session.add_all([helper_a, helper_b])
        await session.flush()

        match = Match(
            user_a_id=min(main_user_id, helper_a.id),
            user_b_id=max(main_user_id, helper_a.id),
            similarity_pct=88,
        )
        session.add(match)
        await session.flush()

        session.add_all(
            [
                Chat(
                    match_id=match.id,
                    user_a_id=min(main_user_id, helper_a.id),
                    user_b_id=max(main_user_id, helper_a.id),
                    firebase_chat_id=f"{prefix}delete_chat",
                ),
                Friend(
                    requester_id=main_user_id,
                    addressee_id=helper_a.id,
                    status=FriendStatus.accepted,
                ),
                Block(blocker_id=main_user_id, blocked_id=helper_b.id),
                Report(
                    reporter_id=main_user_id,
                    reported_id=helper_a.id,
                    reason="spam",
                    details="delete-account regression",
                ),
                MatchDecision(
                    user_id=main_user_id,
                    target_user_id=helper_b.id,
                    decision="like",
                ),
                RoomParticipant(
                    room_id=room_id,
                    user_id=helper_a.id,
                    role=RoomParticipantRole.guest,
                    status=RoomParticipantStatus.connected,
                ),
                PlaylistTrack(
                    playlist_id=playlist_id,
                    spotify_track_id="delete-track-1",
                    position=0,
                ),
            ]
        )
        await session.commit()
        return {"helper_a_id": helper_a.id, "helper_b_id": helper_b.id, "match_id": match.id}


async def _assert_delete_cleanup(user_id: int) -> None:
    async with AsyncSessionLocal() as session:
        checks = {
            "listening_history": await session.scalar(
                select(func.count(ListeningHistory.id)).where(ListeningHistory.user_id == user_id)
            ),
            "user_genres": await session.scalar(
                select(func.count(UserGenre.id)).where(UserGenre.user_id == user_id)
            ),
            "user_moods": await session.scalar(
                select(func.count(UserMood.id)).where(UserMood.user_id == user_id)
            ),
            "taste_vectors": await session.scalar(
                select(func.count(TasteVector.id)).where(TasteVector.user_id == user_id)
            ),
            "match_decisions": await session.scalar(
                select(func.count(MatchDecision.id)).where(MatchDecision.user_id == user_id)
            ),
            "matches": await session.scalar(
                select(func.count(Match.id)).where((Match.user_a_id == user_id) | (Match.user_b_id == user_id))
            ),
            "chats": await session.scalar(
                select(func.count(Chat.id)).where((Chat.user_a_id == user_id) | (Chat.user_b_id == user_id))
            ),
            "friends": await session.scalar(
                select(func.count(Friend.id)).where(
                    (Friend.requester_id == user_id) | (Friend.addressee_id == user_id)
                )
            ),
            "blocks": await session.scalar(
                select(func.count(Block.id)).where((Block.blocker_id == user_id) | (Block.blocked_id == user_id))
            ),
            "reports": await session.scalar(
                select(func.count(Report.id)).where(
                    (Report.reporter_id == user_id) | (Report.reported_id == user_id)
                )
            ),
            "room_participants": await session.scalar(
                select(func.count(RoomParticipant.id)).where(RoomParticipant.user_id == user_id)
            ),
            "active_listening_rooms": await session.scalar(
                select(func.count(ListeningRoom.id)).where(
                    ListeningRoom.host_id == user_id,
                    ListeningRoom.is_active == True,
                )
            ),
            "playlists": await session.scalar(
                select(func.count(Playlist.id)).where(Playlist.owner_id == user_id)
            ),
            "user_record": await session.scalar(select(func.count(User.id)).where(User.id == user_id)),
        }

    for name, count in checks.items():
        assert count == 0, f"{name} still present after delete: {count}"

    redis = await aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    try:
        for key in (
            f"taste_vector:{user_id}",
            f"now_playing:{user_id}",
            f"match_candidates:{user_id}",
        ):
            assert await redis.get(key) is None, f"Redis key still present: {key}"
    finally:
        await redis.aclose()


async def main() -> None:
    prefix = f"week4part3_{int(time.time())}_"
    email = f"{prefix}user@example.com"
    username = f"{prefix}user"
    password = "Password123"
    new_password = "Newpassword123"
    token = None
    user_id = None

    await _cleanup(prefix)

    try:
        async with httpx.AsyncClient(base_url=BASE_URL, timeout=60.0) as client:
            response = _print_step(1, "GET /health", await client.get("/health"))
            assert response.status_code == 200, response.text
            payload = response.json()
            assert payload["status"] == "ok", payload
            assert payload["db"] == "connected", payload
            assert payload["redis"] == "connected", payload
            assert payload["firebase"] == "connected", payload

            register_payload = {
                "email": email,
                "username": username,
                "password": password,
                "first_name": "Test",
                "last_name": "User",
                "birth_date": str(date(2000, 1, 1)),
                "city": "Astana",
            }
            response = _print_step(2, "POST /auth/register", await client.post("/auth/register", json=register_payload))
            assert response.status_code == 201, response.text
            token = response.json()["access_token"]
            user_id = response.json()["user"]["id"]

            login_payload = {"email": email, "password": password}
            response = _print_step(3, "POST /auth/login", await client.post("/auth/login", json=login_payload))
            assert response.status_code == 200, response.text
            token = response.json()["access_token"]
            headers = _auth_headers(token)

            user = await _fetch_user(email)
            assert user and user.verification_code, "verification code missing"
            response = _print_step(
                4,
                "POST /auth/verify-email",
                await client.post("/auth/verify-email", json={"email": email, "code": user.verification_code}),
            )
            assert response.status_code == 200, response.text

            response = _print_step(5, "GET /users/me", await client.get("/users/me", headers=headers))
            assert response.status_code == 200, response.text
            me_payload = response.json()
            assert me_payload["email"] == email, me_payload
            assert me_payload["is_verified"] is True, me_payload

            response = _print_step(
                6,
                "GET /auth/check-username",
                await client.get("/auth/check-username", params={"username": username}),
            )
            assert response.status_code == 200, response.text
            assert response.json()["available"] is False, response.json()

            response = _print_step(
                7,
                "POST /users/me/genres",
                await client.post(
                    "/users/me/genres",
                    headers=headers,
                    json={"genres": ["indie_rock", "pop", "electronic", "lo_fi", "ambient"]},
                ),
            )
            assert response.status_code == 200, response.text

            response = _print_step(
                8,
                "POST /users/me/moods",
                await client.post(
                    "/users/me/moods",
                    headers=headers,
                    json={"moods": ["study", "late_night", "sad"]},
                ),
            )
            assert response.status_code == 200, response.text

            response = _print_step(
                9,
                "GET /tracks/search?q=radiohead",
                await client.get("/tracks/search", headers=headers, params={"q": "radiohead"}),
            )
            assert response.status_code == 200, response.text
            tracks = response.json()
            assert isinstance(tracks, list) and tracks, tracks

            response = _print_step(10, "GET /search/trending", await client.get("/search/trending"))
            assert response.status_code == 200, response.text
            assert isinstance(response.json(), list), response.text

            response = _print_step(
                11,
                'POST /tracks/123/play',
                await client.post(
                    "/tracks/123/play",
                    headers=headers,
                    json={"completion_pct": 95, "title": "Creep", "artist": "Radiohead"},
                ),
            )
            assert response.status_code == 200, response.text

            response = _print_step(12, "GET /taste-vector/me", await client.get("/taste-vector/me", headers=headers))
            assert response.status_code == 200, response.text
            vector_payload = response.json()
            assert vector_payload["vector"], vector_payload

            response = _print_step(
                13,
                "GET /tracks/recommendations",
                await client.get("/tracks/recommendations", headers=headers),
            )
            assert response.status_code == 200, response.text
            assert isinstance(response.json(), list), response.text

            response = _print_step(
                14,
                "POST /playlists",
                await client.post(
                    "/playlists",
                    headers=headers,
                    json={"name": "Test", "visibility": "public"},
                ),
            )
            assert response.status_code == 201, response.text
            playlist_id = response.json()["id"]

            redis = await aioredis.from_url(settings.REDIS_URL, decode_responses=True)
            try:
                await redis.delete("weather:astana", "weather:playlist:astana")
            finally:
                await redis.aclose()

            response = _print_step(
                15,
                "GET /weather/current?city=Astana",
                await client.get("/weather/current", headers=headers, params={"city": "Astana"}),
            )
            assert response.status_code == 200, response.text
            weather_payload = response.json()
            assert weather_payload["city"] == "Astana", weather_payload

            response = _print_step(
                16,
                "GET /weather/playlist?city=Astana",
                await client.get("/weather/playlist", headers=headers, params={"city": "Astana"}),
            )
            assert response.status_code == 200, response.text
            playlist_payload = response.json()
            assert len(playlist_payload["playlists"]) == 3, playlist_payload

            response = _print_step(
                17,
                "GET /charts/city?city=Astana",
                await client.get("/charts/city", params={"city": "Astana"}),
            )
            assert response.status_code == 200, response.text
            assert isinstance(response.json(), list), response.text

            response = _print_step(
                18,
                "POST /auth/forgot-password",
                await client.post("/auth/forgot-password", json={"email": email}),
            )
            assert response.status_code == 200, response.text

            user = await _fetch_user(email)
            assert user and user.reset_code, "reset code missing"
            response = _print_step(
                19,
                "POST /auth/verify-reset-code",
                await client.post(
                    "/auth/verify-reset-code",
                    json={"email": email, "code": user.reset_code},
                ),
            )
            assert response.status_code == 200, response.text
            reset_token = response.json()["reset_token"]

            response = _print_step(
                20,
                "POST /auth/reset-password",
                await client.post(
                    "/auth/reset-password",
                    json={"reset_token": reset_token, "new_password": new_password},
                ),
            )
            assert response.status_code == 200, response.text

            response = _print_step(21, "GET /matches", await client.get("/matches", headers=headers))
            assert response.status_code == 200, response.text
            assert "candidates" in response.json(), response.json()

            response = _print_step(22, "GET /chats", await client.get("/chats", headers=headers))
            assert response.status_code == 200, response.text
            assert response.json() == [], response.json()

            response = _print_step(23, "GET /friends", await client.get("/friends", headers=headers))
            assert response.status_code == 200, response.text
            assert response.json()["friends"] == [], response.json()

            response = _print_step(
                24,
                "POST /rooms/create",
                await client.post("/rooms/create", headers=headers, json={}),
            )
            assert response.status_code == 201, response.text
            room_id = response.json()["room_id"]
            assert response.json()["ws_token"], response.json()
            assert response.json()["ws_url"], response.json()

            await _seed_delete_dependencies(prefix, user_id, playlist_id, room_id)

            redis = await aioredis.from_url(settings.REDIS_URL, decode_responses=True)
            try:
                await redis.set(f"taste_vector:{user_id}", "seeded")
                await redis.set(f"now_playing:{user_id}", "seeded")
                await redis.set(f"match_candidates:{user_id}", "seeded")
                await redis.set(f"match_candidates:{user_id}:astana:10", "seeded")
            finally:
                await redis.aclose()

            response = _print_step(25, "DELETE /users/me", await client.delete("/users/me", headers=headers))
            assert response.status_code == 200, response.text
            assert response.json()["message"] == "account deleted", response.json()
            await _assert_delete_cleanup(user_id)
            print("Delete audit -> PASS")

            response = _print_step(26, "GET /users/me after delete", await client.get("/users/me", headers=headers))
            assert response.status_code == 401, response.text

        print("All 26 requested tests passed.")
    finally:
        await _cleanup(prefix)


if __name__ == "__main__":
    asyncio.run(main())
