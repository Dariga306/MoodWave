from typing import Optional

from pydantic import BaseModel

from app.models.music import ListeningAction


class TrackResponse(BaseModel):
    spotify_id: str
    title: str
    artist: str
    album: Optional[str] = None
    genre: Optional[str] = None
    cover_url: Optional[str] = None
    preview_url: Optional[str] = None
    duration_ms: Optional[int] = None


class HistoryRequest(BaseModel):
    spotify_track_id: str
    action: ListeningAction
