from datetime import date, datetime
from typing import Optional

from sqlalchemy import String, Boolean, DateTime, Date, Integer, Float, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    first_name: Mapped[Optional[str]] = mapped_column(String(100))
    last_name: Mapped[Optional[str]] = mapped_column(String(100))
    display_name: Mapped[Optional[str]] = mapped_column(String(100))
    avatar_url: Mapped[Optional[str]] = mapped_column(Text)
    bio: Mapped[Optional[str]] = mapped_column(String(300))
    birth_date: Mapped[Optional[date]] = mapped_column(Date)
    city: Mapped[Optional[str]] = mapped_column(String(100))
    phone: Mapped[Optional[str]] = mapped_column(String(20), unique=True, nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    avatar_preset: Mapped[int] = mapped_column(Integer, default=0)
    banner_preset: Mapped[int] = mapped_column(Integer, default=0)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    show_activity: Mapped[bool] = mapped_column(Boolean, default=True)
    fcm_token: Mapped[Optional[str]] = mapped_column(Text)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)

    # Email verification
    verification_code: Mapped[Optional[str]] = mapped_column(String(6))
    verification_code_expires: Mapped[Optional[datetime]] = mapped_column(DateTime)
    verification_resend_count: Mapped[int] = mapped_column(Integer, default=0)
    verification_resend_window: Mapped[Optional[datetime]] = mapped_column(DateTime)

    # Password reset — 6-digit code phase
    reset_code: Mapped[Optional[str]] = mapped_column(String(6))
    reset_code_expires: Mapped[Optional[datetime]] = mapped_column(DateTime)

    # Password reset — token phase (after code verified)
    reset_token: Mapped[Optional[str]] = mapped_column(String(512))
    reset_token_expires: Mapped[Optional[datetime]] = mapped_column(DateTime)

    # Account deactivation / scheduled deletion
    deactivated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    delete_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    deletion_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    genres: Mapped[list["UserGenre"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    moods: Mapped[list["UserMood"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    taste_vector: Mapped[Optional["TasteVector"]] = relationship(back_populates="user", uselist=False, cascade="all, delete-orphan")


class UserGenre(Base):
    __tablename__ = "user_genres"
    __table_args__ = (UniqueConstraint("user_id", "genre", name="uq_user_genres_user_genre"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    genre: Mapped[str] = mapped_column(String(100), nullable=False)
    weight: Mapped[float] = mapped_column(Float, default=1.0)

    user: Mapped["User"] = relationship(back_populates="genres")


class UserMood(Base):
    __tablename__ = "user_moods"
    __table_args__ = (UniqueConstraint("user_id", "mood", name="uq_user_moods_user_mood"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    mood: Mapped[str] = mapped_column(String(50), nullable=False)
    weight: Mapped[float] = mapped_column(Float, default=1.0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="moods")


class TasteVector(Base):
    __tablename__ = "taste_vectors"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    vector: Mapped[dict] = mapped_column(JSONB, default=dict)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="taste_vector")
