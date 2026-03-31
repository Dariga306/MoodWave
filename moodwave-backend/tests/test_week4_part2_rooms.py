import asyncio
import json
import time
from typing import Any

import httpx
import websockets
from sqlalchemy import select

from app.database import AsyncSessionLocal
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
            is_active=True,
            is_verified=True,
            is_public=True,
            fcm_token="token-room-user-1",
        )
        user2 = User(
            email=f"{prefix}2@example.com",
            username=f"{prefix}user2",
            hashed_password=hash_password("password123"),
            first_name="Daniyar",
            is_active=True,
            is_verified=True,
            is_public=True,
            fcm_token="token-room-user-2",
        )
        session.add_all([user1, user2])
        await session.commit()

        return {
            "user1_id": user1.id,
            "user2_id": user2.id,
            "user1_token": create_access_token(user1.id),
            "user2_token": create_access_token(user2.id),
        }


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def _recv_json(ws, timeout: float = 5.0) -> dict[str, Any]:
    message = await asyncio.wait_for(ws.recv(), timeout=timeout)
    return json.loads(message)


async def main() -> None:
    prefix = f"week4rooms{int(time.time())}_"
    seeded = await _seed(prefix)

    try:
        async with httpx.AsyncClient(base_url="http://127.0.0.1:8000", timeout=30.0) as client:
            host_headers = _auth_headers(seeded["user1_token"])
            guest_headers = _auth_headers(seeded["user2_token"])

            response = await client.post(
                "/rooms/create",
                headers=host_headers,
                json={"name": "Winter Vibes Night", "is_public": True, "max_guests": 10},
            )
            assert response.status_code == 201, response.text
            created = response.json()
            assert created["room_id"], created
            assert created["ws_token"], created
            assert created["ws_url"], created
            room_id = created["room_id"]
            host_ws_url = created["ws_url"]

            response = await client.post(f"/rooms/{room_id}/join-request", headers=guest_headers)
            assert response.status_code == 202, response.text
            assert response.json()["message"] == "Request sent, waiting for host approval", response.json()

            response = await client.post(
                f"/rooms/{room_id}/join-approve",
                headers=host_headers,
                json={"user_id": seeded["user2_id"]},
            )
            assert response.status_code == 200, response.text
            approved = response.json()
            assert approved["message"] == "approved", approved
            assert approved["ws_token"], approved
            guest_ws_url = f"ws://localhost:8000/ws/rooms/{room_id}?token={approved['ws_token']}"

            async with websockets.connect(host_ws_url) as host_ws:
                host_sync = await _recv_json(host_ws)
                assert host_sync["event"] == "sync", host_sync
                assert host_sync["state"] == {}, host_sync

                async with websockets.connect(guest_ws_url) as guest_ws:
                    guest_sync = await _recv_json(guest_ws)
                    assert guest_sync["event"] == "sync", guest_sync
                    assert guest_sync["state"] == {}, guest_sync

                    host_guest_joined = await _recv_json(host_ws)
                    assert host_guest_joined["event"] == "guest_joined", host_guest_joined
                    assert host_guest_joined["user_id"] == seeded["user2_id"], host_guest_joined
                    assert host_guest_joined["username"] == f"{prefix}user2", host_guest_joined

                    await host_ws.send(
                        json.dumps(
                            {
                                "event": "play",
                                "track_spotify_id": "123",
                                "track_title": "Sweater Weather",
                                "track_artist": "The Neighbourhood",
                                "position_ms": 0,
                            }
                        )
                    )

                    guest_play_sync = await _recv_json(guest_ws)
                    assert guest_play_sync["event"] == "sync", guest_play_sync
                    state = guest_play_sync["state"]
                    assert state["track_spotify_id"] == "123", state
                    assert state["track_title"] == "Sweater Weather", state
                    assert state["track_artist"] == "The Neighbourhood", state
                    assert state["is_playing"] is True, state
                    assert state["position_ms"] >= 0, state

                    response = await client.post(f"/rooms/{room_id}/close", headers=host_headers)
                    assert response.status_code == 200, response.text
                    assert response.json()["message"] == "Room closed", response.json()

                    guest_room_closed = await _recv_json(guest_ws)
                    assert guest_room_closed["event"] == "room_closed", guest_room_closed

        print("All 7 requested tests passed.")
    finally:
        await _cleanup(prefix)


if __name__ == "__main__":
    asyncio.run(main())
