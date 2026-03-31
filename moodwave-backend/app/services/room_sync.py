import time

from fastapi import WebSocket


class RoomConnectionManager:
    def __init__(self):
        self.rooms: dict[int, dict[int, WebSocket]] = {}

    async def connect(self, room_id: int, user_id: int, websocket: WebSocket):
        await websocket.accept()
        if room_id not in self.rooms:
            self.rooms[room_id] = {}
        self.rooms[room_id][user_id] = websocket

    def disconnect(self, room_id: int, user_id: int):
        if room_id in self.rooms:
            self.rooms[room_id].pop(user_id, None)
            if not self.rooms[room_id]:
                del self.rooms[room_id]

    async def broadcast(self, room_id: int, message: dict, exclude_user_id: int = None):
        if room_id not in self.rooms:
            return
        disconnected = []
        for uid, ws in self.rooms[room_id].items():
            if uid == exclude_user_id:
                continue
            try:
                await ws.send_json(message)
            except Exception:
                disconnected.append(uid)
        for uid in disconnected:
            self.disconnect(room_id, uid)

    async def send_to_user(self, room_id: int, user_id: int, message: dict):
        ws = self.rooms.get(room_id, {}).get(user_id)
        if ws:
            try:
                await ws.send_json(message)
            except Exception:
                self.disconnect(room_id, user_id)


manager = RoomConnectionManager()


def adjust_position(state: dict, latency_ms: int = 50) -> int:
    if not state.get("is_playing"):
        return state.get("position_ms", 0)
    elapsed = (time.time() - state["updated_at"]) * 1000
    return int(state["position_ms"] + elapsed + latency_ms / 2)
