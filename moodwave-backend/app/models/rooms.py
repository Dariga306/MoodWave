from datetime import datetime
from typing import Optional

from sqlalchemy import String, Boolean, DateTime, Integer, ForeignKey, Enum, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
import enum

from app.database import Base


class RoomParticipantRole(str, enum.Enum):
    host = "host"
    guest = "guest"


class RoomParticipantStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    connected = "connected"
    disconnected = "disconnected"


class ListeningRoom(Base):
    __tablename__ = "listening_rooms"

    id: Mapped[int] = mapped_column(primary_key=True)
    host_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500))
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    max_guests: Mapped[int] = mapped_column(Integer, default=10)
    current_track_spotify_id: Mapped[Optional[str]] = mapped_column(String(100))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    closed_at: Mapped[Optional[datetime]] = mapped_column(DateTime)

    participants: Mapped[list["RoomParticipant"]] = relationship(back_populates="room", cascade="all, delete-orphan")


class RoomParticipant(Base):
    __tablename__ = "room_participants"

    id: Mapped[int] = mapped_column(primary_key=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("listening_rooms.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[RoomParticipantRole] = mapped_column(Enum(RoomParticipantRole), nullable=False)
    status: Mapped[RoomParticipantStatus] = mapped_column(Enum(RoomParticipantStatus), default=RoomParticipantStatus.pending)
    joined_at: Mapped[Optional[datetime]] = mapped_column(DateTime)
    left_at: Mapped[Optional[datetime]] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    room: Mapped["ListeningRoom"] = relationship(back_populates="participants")
