from datetime import datetime
from typing import Optional

from sqlalchemy import String, Boolean, DateTime, Integer, Float, ForeignKey, Text, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB
import enum

from app.database import Base


class ListeningAction(str, enum.Enum):
    played = "played"
    liked = "liked"
    disliked = "disliked"
    skipped = "skipped"
    skipped_early = "skipped_early"
    completed = "completed"
    replayed = "replayed"
    added_to_playlist = "added_to_playlist"


class PlaylistVisibility(str, enum.Enum):
    public = "public"
    friends = "friends"
    private = "private"


class TrackCache(Base):
    __tablename__ = "tracks_cache"

    id: Mapped[int] = mapped_column(primary_key=True)
    spotify_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    artist: Mapped[str] = mapped_column(String(255), nullable=False)
    album: Mapped[Optional[str]] = mapped_column(String(255))
    cover_url: Mapped[Optional[str]] = mapped_column(Text)
    preview_url: Mapped[Optional[str]] = mapped_column(Text)
    duration_ms: Mapped[Optional[int]] = mapped_column(Integer)
    genres: Mapped[list] = mapped_column(JSONB, default=list)
    audio_features: Mapped[dict] = mapped_column(JSONB, default=dict)
    cached_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ListeningHistory(Base):
    __tablename__ = "listening_history"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    spotify_track_id: Mapped[str] = mapped_column(String(100), index=True)
    action: Mapped[ListeningAction] = mapped_column(Enum(ListeningAction), nullable=False)
    weight: Mapped[float] = mapped_column(Float, default=1.0)
    completion_pct: Mapped[Optional[float]] = mapped_column(Float)
    mood: Mapped[Optional[str]] = mapped_column(String(50))
    time_listened_ms: Mapped[Optional[int]] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Playlist(Base):
    __tablename__ = "playlists"

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    collab_user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500))
    cover_url: Mapped[Optional[str]] = mapped_column(Text)
    visibility: Mapped[PlaylistVisibility] = mapped_column(Enum(PlaylistVisibility), default=PlaylistVisibility.private)
    is_collaborative: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    tracks: Mapped[list["PlaylistTrack"]] = relationship(back_populates="playlist", cascade="all, delete-orphan", order_by="PlaylistTrack.position")


class PlaylistTrack(Base):
    __tablename__ = "playlist_tracks"

    id: Mapped[int] = mapped_column(primary_key=True)
    playlist_id: Mapped[int] = mapped_column(ForeignKey("playlists.id", ondelete="CASCADE"), index=True)
    spotify_track_id: Mapped[str] = mapped_column(String(100), nullable=False)
    position: Mapped[int] = mapped_column(Integer, default=0)
    added_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    playlist: Mapped["Playlist"] = relationship(back_populates="tracks")
