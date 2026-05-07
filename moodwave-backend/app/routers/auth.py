import asyncio
import logging
import os
from collections import defaultdict
from datetime import date, datetime, timedelta
from difflib import SequenceMatcher
from pathlib import Path
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request, UploadFile
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import and_, func, or_, select, true
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

from app.dependencies import get_db, get_current_user
from app.models.chat import Chat
from app.models.rooms import ListeningRoom, RoomParticipant, RoomParticipantStatus
from app.models.music import (
    ListeningHistory,
    Playlist,
    PlaylistTrack,
    PlaylistVisibility,
    TrackCache,
)
from app.models.social import ArtistFollow, Friend, FriendStatus, Match, UserFollow
from app.models.user import User, UserGenre, UserMood, TasteVector
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
    VerifyEmailRequest,
    ResendVerificationRequest,
    ForgotPasswordRequest,
    VerifyResetCodeRequest,
    ResetPasswordRequest,
)
from app.services.auth import (
    create_access_token,
    create_refresh_token,
    create_reset_token,
    hash_password,
    verify_password,
    verify_refresh_token,
    verify_reset_token,
)
from app.services import cache as cache_svc
from app.services import deezer as deezer_service
from app.services.email_service import (
    send_verification_email, send_reset_email,
    send_account_deletion_email, send_reactivation_email,
    send_login_email,
)
from app.services.security import are_friends, get_blocked_ids_for_user
from app.utils.code_generator import generate_code, is_code_expired

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)

ALLOWED_GENRES = {
    "pop", "rock", "indie rock", "alt pop", "electronic", "hip-hop", "r&b", "jazz",
    "classical", "ambient", "lo-fi", "k-pop", "latin", "reggae", "metal", "punk",
    "punk rock", "post-punk", "emo", "hardcore", "alternative", "grunge", "folk",
    "country", "blues", "soul", "funk", "disco", "house", "techno", "drum & bass",
    "dubstep", "trap", "phonk", "afrobeats", "bossa nova", "synthwave", "vaporwave",
    "shoegaze", "math rock", "post-rock", "noise rock",
}

VALID_MOODS = {"study", "workout", "sleep", "driving", "party", "sad", "morning", "late_night"}
GENRE_ALIASES = {
    "indie rock": "indie rock",
    "lo fi": "lo-fi",
    "hip hop": "hip-hop",
    "r b": "r&b",
    "r and b": "r&b",
    "drum and bass": "drum & bass",
    "alt pop": "alt pop",
    "post punk": "post-punk",
    "k pop": "k-pop",
}

CODE_TTL_MINUTES = 15
MAX_RESENDS_PER_HOUR = 3
UPLOADS_DIR = Path(__file__).resolve().parents[2] / "uploads"
PROFILE_UPLOADS_DIR = UPLOADS_DIR / "profiles"

RU_MONTHS_SHORT = {
    1: "Jan",
    2: "Feb",
    3: "Mar",
    4: "Apr",
    5: "May",
    6: "Jun",
    7: "Jul",
    8: "Aug",
    9: "Sep",
    10: "Oct",
    11: "Nov",
    12: "Dec",
}


# ---------------------------------------------------------------------------
# Inline request/body models (not in schemas/auth.py to avoid cluttering)
# ---------------------------------------------------------------------------

class RefreshRequest(BaseModel):
    refresh_token: str


class UpdateProfileRequest(BaseModel):
    username: Optional[str] = Field(default=None, min_length=3, max_length=50)
    first_name: Optional[str] = Field(default=None, max_length=100)
    last_name: Optional[str] = Field(default=None, max_length=100)
    display_name: Optional[str] = Field(default=None, max_length=100)
    bio: Optional[str] = Field(default=None, max_length=150)
    city: Optional[str] = Field(default=None, max_length=100)
    avatar_url: Optional[str] = Field(default=None, max_length=1000)
    banner_url: Optional[str] = Field(default=None, max_length=1000)
    gender: Optional[str] = Field(default=None, max_length=20)
    avatar_preset: Optional[int] = Field(default=None, ge=0, le=11)
    banner_preset: Optional[int] = Field(default=None, ge=0, le=5)
    is_public: Optional[bool] = None
    show_activity: Optional[bool] = None
    show_followers: Optional[bool] = None
    show_recently_played: Optional[bool] = None
    hide_music_taste: Optional[bool] = None


class FCMTokenRequest(BaseModel):
    fcm_token: str = Field(min_length=1, max_length=4096)


class GenreItem(BaseModel):
    genre: str
    weight: float = 0.5


class GenresRequest(BaseModel):
    genres: list[str | GenreItem]


class MoodItem(BaseModel):
    mood: str
    weight: float = 0.5


class MoodsRequest(BaseModel):
    moods: list[str | MoodItem]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _score_user_match(query: str, user: User) -> float:
    q = query.lower().strip()
    best = 0.0
    for candidate in (user.username or "", user.display_name or ""):
        text = candidate.lower()
        if not text:
            continue
        if text == q:
            score = 100.0
        elif text.startswith(q):
            score = 80.0
        elif q in text:
            score = 60.0
        else:
            ratio = SequenceMatcher(None, q, text).ratio()
            if ratio < 0.5:
                continue
            score = 30.0 + ratio * 20.0
        best = max(best, score)
    return best


def _calculate_age(birth_date: date) -> int:
    today = date.today()
    return today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))


def _normalize_genre(genre: str) -> str:
    normalized = genre.strip().lower().replace("_", " ").replace("-", " ")
    normalized = " ".join(normalized.split())
    return GENRE_ALIASES.get(normalized, normalized)


def _normalize_mood(mood: str) -> str:
    return "_".join(mood.strip().lower().replace("-", " ").split())


def _coerce_bool(value: object) -> bool | None:
    if value is None or isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"true", "1", "yes", "on"}:
            return True
        if normalized in {"false", "0", "no", "off"}:
            return False
    return None


def _coerce_int(value: object) -> int | None:
    if value is None or isinstance(value, int):
        return value
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        try:
            return int(stripped)
        except ValueError:
            return None
    return None


def _build_absolute_upload_url(request: Request, relative_path: str) -> str:
    return str(request.url_for("uploads", path=relative_path))


async def _save_profile_image(
    request: Request,
    upload: UploadFile,
    *,
    user_id: int,
    kind: str,
) -> str:
    ext = os.path.splitext(upload.filename or "")[1].lower()
    if not ext:
        content_type = (upload.content_type or "").lower()
        guessed_ext = content_type.split("/")[-1]
        ext = ".jpg" if guessed_ext == "jpeg" else f".{guessed_ext}"
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        raise HTTPException(status_code=400, detail=f"Unsupported {kind} format")

    content_type = (upload.content_type or "").lower()
    if content_type and not (
        content_type.startswith("image/") or content_type == "application/octet-stream"
    ):
        raise HTTPException(status_code=400, detail=f"{kind.title()} must be an image")

    data = await upload.read()
    if not data:
        raise HTTPException(status_code=400, detail=f"{kind.title()} file is empty")

    PROFILE_UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    file_name = f"user_{user_id}_{kind}_{int(datetime.utcnow().timestamp())}_{uuid4().hex[:10]}{ext}"
    file_path = PROFILE_UPLOADS_DIR / file_name
    file_path.write_bytes(data)
    relative_path = f"profiles/{file_name}".replace("\\", "/")
    return _build_absolute_upload_url(request, relative_path)


async def _parse_profile_update_request(request: Request) -> tuple[dict[str, object], UploadFile | None, UploadFile | None]:
    content_type = request.headers.get("content-type", "").lower()
    avatar_file: UploadFile | None = None
    banner_file: UploadFile | None = None

    if "multipart/form-data" in content_type:
        form = await request.form()
        raw_data: dict[str, object] = {}
        for key in (
            "username",
            "first_name",
            "last_name",
            "display_name",
            "bio",
            "city",
            "avatar_url",
            "banner_url",
            "gender",
            "avatar_preset",
            "banner_preset",
            "is_public",
            "show_activity",
            "show_followers",
            "show_recently_played",
            "hide_music_taste",
        ):
            value = form.get(key)
            if value is not None:
                raw_data[key] = value

        avatar_candidate = form.get("avatar")
        banner_candidate = form.get("banner")
        if isinstance(avatar_candidate, UploadFile) and avatar_candidate.filename:
            avatar_file = avatar_candidate
        if isinstance(banner_candidate, UploadFile) and banner_candidate.filename:
            banner_file = banner_candidate

        for bool_key in ("is_public", "show_activity", "show_followers", "show_recently_played", "hide_music_taste"):
            if bool_key in raw_data:
                parsed = _coerce_bool(raw_data[bool_key])
                if parsed is not None:
                    raw_data[bool_key] = parsed

        for int_key in ("avatar_preset", "banner_preset"):
            if int_key in raw_data:
                parsed = _coerce_int(raw_data[int_key])
                if parsed is not None:
                    raw_data[int_key] = parsed
                else:
                    raw_data.pop(int_key, None)

        if raw_data.get("gender") == "":
            raw_data["gender"] = None
    else:
        raw_json = await request.json()
        if not isinstance(raw_json, dict):
            raise HTTPException(status_code=400, detail="Invalid profile payload")
        raw_data = dict(raw_json)

    validated = UpdateProfileRequest.model_validate(raw_data).model_dump(exclude_none=True)
    return validated, avatar_file, banner_file


def _serialize_user(
    user: User,
    genres: list[UserGenre],
    moods: list[UserMood],
    followers_count: int = 0,
    following_count: int = 0,
) -> UserResponse:
    return UserResponse.model_validate({
        "id": user.id,
        "email": user.email,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "banner_url": getattr(user, "banner_url", None),
        "bio": user.bio,
        "birth_date": user.birth_date,
        "city": user.city,
        "gender": user.gender,
        "avatar_preset": getattr(user, "avatar_preset", 0) or 0,
        "banner_preset": getattr(user, "banner_preset", 0) or 0,
        "is_public": user.is_public,
        "show_activity": user.show_activity,
        "show_followers": getattr(user, "show_followers", True),
        "show_recently_played": getattr(user, "show_recently_played", True),
        "hide_music_taste": getattr(user, "hide_music_taste", False),
        "is_verified": user.is_verified,
        "is_active": user.is_active,
        "is_admin": getattr(user, "is_admin", False),
        "genres": [item.genre for item in genres],
        "moods": [item.mood for item in moods],
        "followers_count": followers_count,
        "following_count": following_count,
        "created_at": user.created_at,
        "updated_at": user.updated_at,
    })


def _public_profile_payload(
    user: User,
    *,
    genres: list[str],
    moods: list[str],
    followers_count: int | None,
    following_count: int | None,
) -> dict[str, object]:
    return {
        "id": user.id,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "banner_url": getattr(user, "banner_url", None),
        "bio": user.bio,
        "birth_date": user.birth_date.isoformat() if user.birth_date else None,
        "city": user.city,
        "gender": user.gender,
        "avatar_preset": getattr(user, "avatar_preset", 0) or 0,
        "banner_preset": getattr(user, "banner_preset", 0) or 0,
        "is_public": user.is_public,
        "show_activity": user.show_activity,
        "show_followers": getattr(user, "show_followers", True),
        "show_recently_played": getattr(user, "show_recently_played", True),
        "hide_music_taste": getattr(user, "hide_music_taste", False),
        "is_verified": user.is_verified,
        "is_active": user.is_active,
        "genres": genres,
        "moods": moods,
        "followers_count": followers_count,
        "following_count": following_count,
        "created_at": user.created_at.isoformat(),
        "updated_at": user.updated_at.isoformat(),
    }


async def _followed_artist_profiles(user_id: int, db: AsyncSession) -> list[dict]:
    rows = (
        await db.execute(
            select(ArtistFollow.deezer_artist_id)
            .where(ArtistFollow.user_id == user_id)
            .order_by(ArtistFollow.created_at.desc())
            .limit(5)
        )
    ).scalars().all()

    if not rows:
        return []

    artists = await asyncio.gather(
        *[deezer_service.get_artist(artist_id) for artist_id in rows],
        return_exceptions=True,
    )
    payload: list[dict] = []
    for artist_id, artist in zip(rows, artists):
        if isinstance(artist, dict) and artist:
            payload.append(artist)
        else:
            payload.append({"id": artist_id, "name": f"Artist {artist_id}"})
    return payload


# ---------------------------------------------------------------------------
# Auth — register / login / refresh
# ---------------------------------------------------------------------------

@router.post(
    "/auth/register",
    response_model=TokenResponse,
    status_code=201,
    summary="Register new user",
    description="Creates a new MoodWave account, generates JWT tokens, and sends an email verification code.",
)
@limiter.limit("5/minute")
async def register(
    request: Request,
    body: RegisterRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    if body.birth_date and _calculate_age(body.birth_date) < 13:
        raise HTTPException(status_code=400, detail="Must be at least 13 years old")

    if await db.scalar(select(User).where(User.email == body.email)):
        raise HTTPException(status_code=400, detail="Email already registered")

    if await db.scalar(select(User).where(User.username == body.username)):
        raise HTTPException(status_code=400, detail="Username already taken")

    # Build display_name from first/last if not supplied directly
    computed_display = body.display_name
    if not computed_display and body.first_name:
        parts = [body.first_name]
        if body.last_name:
            parts.append(body.last_name)
        computed_display = " ".join(parts)

    code = generate_code()
    expires = datetime.utcnow() + timedelta(minutes=CODE_TTL_MINUTES)

    user = User(
        email=body.email,
        username=body.username,
        hashed_password=hash_password(body.password),
        first_name=body.first_name,
        last_name=body.last_name,
        display_name=computed_display,
        birth_date=body.birth_date,
        city=body.city,
        is_active=True,
        is_verified=False,
        verification_code=code,
        verification_code_expires=expires,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    email_sent = await send_verification_email(user.email, code, user.first_name or "")

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user=_serialize_user(user, [], []),
        dev_code=None if email_sent else code,
    )


@router.post(
    "/auth/login",
    response_model=TokenResponse,
    summary="Log in user",
    description="Authenticates the user with email and password and returns fresh access and refresh tokens.",
)
@limiter.limit("10/minute")
async def login(
    request: Request,
    body: LoginRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    user = await db.scalar(select(User).where(User.email == body.email))
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Handle deactivated account (soft-delete with 30-day grace period)
    if not user.is_active and user.deletion_type == "deactivated_30":
        now = datetime.utcnow()
        if user.delete_at and now > user.delete_at:
            raise HTTPException(
                status_code=401,
                detail="Account has been permanently deleted after 30 days of inactivity",
            )
        # Restore account
        user.is_active = True
        user.deactivated_at = None
        user.delete_at = None
        user.deletion_type = None
        await db.commit()
        await db.refresh(user)
        background_tasks.add_task(
            send_reactivation_email, user.email, user.first_name or ""
        )

    elif not user.is_active:
        raise HTTPException(status_code=401, detail="Account is disabled")

    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == user.id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == user.id))).scalars().all()
    background_tasks.add_task(
        send_login_email,
        user.email,
        user.first_name or "",
        request.client.host if request.client else "",
        request.headers.get("user-agent", ""),
    )
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user=_serialize_user(user, genres, moods),
    )


@router.post(
    "/auth/refresh",
    response_model=TokenResponse,
    summary="Refresh access token",
    description="Validates a refresh token and returns a new token pair for the same active user.",
)
async def refresh_token(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = verify_refresh_token(body.refresh_token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = await db.get(User, int(payload["sub"]))
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == user.id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == user.id))).scalars().all()
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user=_serialize_user(user, genres, moods),
    )


# ---------------------------------------------------------------------------
# Auth — username availability
# ---------------------------------------------------------------------------

@router.get(
    "/auth/check-username",
    summary="Check username availability",
    description="Checks whether a username is already taken so the client can validate sign-up input.",
)
async def check_username(
    username: str = Query(min_length=3, max_length=50),
    db: AsyncSession = Depends(get_db),
):
    taken = await db.scalar(
        select(User).where(User.username.ilike(username))
    )
    return {"available": taken is None}


# ---------------------------------------------------------------------------
# Auth — email verification
# ---------------------------------------------------------------------------

@router.post(
    "/auth/verify-email",
    summary="Verify email address",
    description="Validates a six-digit email verification code and marks the user account as verified.",
)
@limiter.limit("10/minute")
async def verify_email(
    request: Request,
    body: VerifyEmailRequest,
    db: AsyncSession = Depends(get_db),
):
    user = await db.scalar(select(User).where(User.email == body.email))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.is_verified:
        return {"message": "Email already verified"}

    if not user.verification_code or user.verification_code != body.code:
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")
    if not user.verification_code_expires or is_code_expired(user.verification_code_expires):
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")

    user.is_verified = True
    user.verification_code = None
    user.verification_code_expires = None
    user.verification_resend_count = 0
    user.verification_resend_window = None
    await db.commit()
    return {"message": "Email verified successfully"}


@router.post(
    "/auth/resend-verification",
    summary="Resend verification code",
    description="Sends a fresh email verification code with resend-rate protection for unverified accounts.",
)
@limiter.limit("5/minute")
async def resend_verification(
    request: Request,
    body: ResendVerificationRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    user = await db.scalar(select(User).where(User.email == body.email))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.is_verified:
        raise HTTPException(status_code=400, detail="Already verified")

    now = datetime.utcnow()
    window_start = user.verification_resend_window
    count = user.verification_resend_count or 0

    # Reset window if more than 1 hour has passed
    if not window_start or (now - window_start).total_seconds() > 3600:
        count = 0
        window_start = now

    if count >= MAX_RESENDS_PER_HOUR:
        raise HTTPException(status_code=429, detail="Too many resend requests. Try again in 1 hour.")

    code = generate_code()
    user.verification_code = code
    user.verification_code_expires = now + timedelta(minutes=CODE_TTL_MINUTES)
    user.verification_resend_count = count + 1
    user.verification_resend_window = window_start
    await db.commit()

    email_sent = await send_verification_email(user.email, code, user.first_name or "")
    return {"message": "Code sent", "dev_code": None if email_sent else code}


# ---------------------------------------------------------------------------
# Auth — password recovery
# ---------------------------------------------------------------------------

@router.post(
    "/auth/forgot-password",
    summary="Start password reset",
    description="Sends a password reset code to the provided email address and always returns a safe generic response.",
)
@limiter.limit("3/minute")
async def forgot_password(
    request: Request,
    body: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    user = await db.scalar(select(User).where(User.email == body.email))
    if user and user.is_active:
        code = generate_code()
        user.reset_code = code
        user.reset_code_expires = datetime.utcnow() + timedelta(minutes=CODE_TTL_MINUTES)
        await db.commit()
        email_sent = await send_reset_email(user.email, code, user.first_name or "")
        return {
            "message": "If this email exists, a code was sent",
            "method": "email",
            "dev_code": None if email_sent else code,
        }

    return {"message": "If this email exists, a code was sent", "method": "email", "dev_code": None}


@router.post(
    "/auth/verify-reset-code",
    summary="Verify reset code",
    description="Validates the password reset code and returns a short-lived reset token for changing the password.",
)
@limiter.limit("10/minute")
async def verify_reset_code(
    request: Request,
    body: VerifyResetCodeRequest,
    db: AsyncSession = Depends(get_db),
):
    user = await db.scalar(select(User).where(User.email == body.email))
    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    if not user.reset_code or user.reset_code != body.code:
        raise HTTPException(status_code=400, detail="Invalid or expired code")
    if not user.reset_code_expires or is_code_expired(user.reset_code_expires):
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    # Consume the 6-digit code and issue a short-lived reset token (stored in DB)
    reset_token = create_reset_token(user.id)
    user.reset_code = None
    user.reset_code_expires = None
    user.reset_token = reset_token
    user.reset_token_expires = datetime.utcnow() + timedelta(minutes=10)
    await db.commit()

    return {"reset_token": reset_token}


@router.post(
    "/auth/reset-password",
    summary="Reset password",
    description="Consumes a valid reset token and saves a new password for the account.",
)
@limiter.limit("10/minute")
async def reset_password(
    request: Request,
    body: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    # 1. Verify JWT structure and type
    payload = verify_reset_token(body.reset_token)
    if not payload:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    user = await db.get(User, int(payload["sub"]))
    if not user or not user.is_active:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    # 2. Verify token matches DB-stored copy (one-time use)
    now = datetime.utcnow()
    if (
        not user.reset_token
        or user.reset_token != body.reset_token
        or not user.reset_token_expires
        or user.reset_token_expires < now
    ):
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    # 3. Apply new password and consume the token
    user.hashed_password = hash_password(body.new_password)
    user.reset_token = None
    user.reset_token_expires = None
    await db.commit()
    return {"message": "Password reset successfully"}


# ---------------------------------------------------------------------------
# Auth — change password (authenticated)
# ---------------------------------------------------------------------------

@router.post(
    "/auth/change-password",
    summary="Change password",
    description="Allows an authenticated user to change their password by verifying the current one first.",
)
async def change_password(
    body: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(body.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    current_user.hashed_password = hash_password(body.new_password)
    await db.commit()
    return {"message": "Password changed successfully"}


# ---------------------------------------------------------------------------
# Users — /users/me
# ---------------------------------------------------------------------------

@router.get(
    "/users/me",
    response_model=UserResponse,
    summary="Get current profile",
    description="Returns the authenticated user's full profile, including selected genres and moods.",
)
async def get_me(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == current_user.id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == current_user.id))).scalars().all()
    followers_count = await db.scalar(
        select(func.count(UserFollow.id)).where(UserFollow.following_id == current_user.id)
    ) or 0
    following_count = await db.scalar(
        select(func.count(UserFollow.id)).where(UserFollow.follower_id == current_user.id)
    ) or 0
    artist_following_count = await db.scalar(
        select(func.count(ArtistFollow.id)).where(ArtistFollow.user_id == current_user.id)
    ) or 0
    following_count += artist_following_count
    return _serialize_user(current_user, genres, moods, followers_count, following_count)


@router.put(
    "/users/me",
    response_model=UserResponse,
    summary="Update current profile",
    description="Updates editable profile fields such as name, bio, city, privacy, and activity visibility.",
)
async def update_me(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data, avatar_file, banner_file = await _parse_profile_update_request(request)
    if "username" in data and data["username"] != current_user.username:
        existing = await db.scalar(
            select(User).where(User.username == data["username"], User.id != current_user.id)
        )
        if existing:
            raise HTTPException(status_code=400, detail="Username already taken")
        if current_user.last_username_change:
            days_since = (datetime.utcnow() - current_user.last_username_change).days
            if days_since < 30:
                raise HTTPException(
                    status_code=403,
                    detail=f"Вы сможете сменить ник через {30 - days_since} дней",
                )
        data["last_username_change"] = datetime.utcnow()

    if avatar_file is not None:
        data["avatar_url"] = await _save_profile_image(
            request,
            avatar_file,
            user_id=current_user.id,
            kind="avatar",
        )
    if banner_file is not None:
        data["banner_url"] = await _save_profile_image(
            request,
            banner_file,
            user_id=current_user.id,
            kind="banner",
        )

    for key, value in data.items():
        setattr(current_user, key, value)
    await db.commit()
    await db.refresh(current_user)
    if {"is_public", "username", "display_name"} & set(data.keys()):
        try:
            await cache_svc.invalidate_all_search_results(request.app.state.redis)
        except Exception:
            pass

    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == current_user.id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == current_user.id))).scalars().all()
    followers_count = await db.scalar(
        select(func.count(UserFollow.id)).where(UserFollow.following_id == current_user.id)
    ) or 0
    following_count = await db.scalar(
        select(func.count(UserFollow.id)).where(UserFollow.follower_id == current_user.id)
    ) or 0
    artist_following_count = await db.scalar(
        select(func.count(ArtistFollow.id)).where(ArtistFollow.user_id == current_user.id)
    ) or 0
    following_count += artist_following_count
    return _serialize_user(current_user, genres, moods, followers_count, following_count)


@router.put(
    "/users/me/fcm-token",
    summary="Update FCM token",
    description="Stores the device FCM token used for push notifications for the authenticated user.",
)
async def update_fcm_token(
    body: FCMTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user.fcm_token = body.fcm_token
    await db.commit()
    return {"ok": True}


@router.post(
    "/users/me/genres",
    summary="Save favorite genres",
    description="Stores the user's onboarding genre selections and updates the persisted taste vector.",
)
async def save_genres(
    body: GenresRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    unique_genres: list[str] = []
    seen: set[str] = set()
    genre_weights: dict[str, float] = {}
    for item in body.genres:
        value = item if isinstance(item, str) else item.genre
        normalized = _normalize_genre(value)
        if normalized not in seen:
            seen.add(normalized)
            unique_genres.append(normalized)
        genre_weights[normalized] = (
            0.5 if isinstance(item, str) else float(item.weight or 0.5)
        )

    if len(unique_genres) > 3:
        raise HTTPException(status_code=400, detail="Select up to 3 genres")

    invalid = [genre for genre in unique_genres if genre not in ALLOWED_GENRES]
    if invalid:
        raise HTTPException(status_code=400, detail=f"Invalid genre name: {', '.join(invalid)}")

    existing = (
        await db.execute(select(UserGenre).where(UserGenre.user_id == current_user.id))
    ).scalars().all()
    existing_map = {row.genre.lower(): row for row in existing}

    for row in existing:
        if row.genre.lower() not in seen:
            await db.delete(row)

    for genre in unique_genres:
        if genre in existing_map:
            existing_map[genre].weight = genre_weights.get(genre, 0.5)
        else:
            db.add(
                UserGenre(
                    user_id=current_user.id,
                    genre=genre,
                    weight=genre_weights.get(genre, 0.5),
                )
            )

    tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    if not tv:
        tv = TasteVector(user_id=current_user.id, vector={})
        db.add(tv)
    vector = {
        key: value
        for key, value in dict(tv.vector or {}).items()
        if not str(key).startswith("genre:")
    }
    for genre in unique_genres:
        vector[f"genre:{genre.replace(' ', '_')}"] = genre_weights.get(genre, 0.5)
    tv.vector = vector

    await db.commit()
    return {"ok": True, "count": len(unique_genres)}


@router.post(
    "/users/me/moods",
    summary="Save favorite moods",
    description="Stores the user's onboarding mood selections and updates the persisted taste vector.",
)
async def save_moods(
    body: MoodsRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    unique_moods: list[str] = []
    seen: set[str] = set()
    for item in body.moods:
        value = item if isinstance(item, str) else item.mood
        normalized = _normalize_mood(value)
        if normalized not in seen:
            seen.add(normalized)
            unique_moods.append(normalized)

    invalid = [mood for mood in unique_moods if mood not in VALID_MOODS]
    if invalid:
        raise HTTPException(status_code=400, detail=f"Invalid mood: {', '.join(invalid)}")

    existing = (
        await db.execute(select(UserMood).where(UserMood.user_id == current_user.id))
    ).scalars().all()
    existing_map = {row.mood.lower(): row for row in existing}

    for mood in unique_moods:
        if mood in existing_map:
            existing_map[mood].weight = 0.5
        else:
            db.add(UserMood(user_id=current_user.id, mood=mood, weight=0.5))

    tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    if not tv:
        tv = TasteVector(user_id=current_user.id, vector={})
        db.add(tv)
    vector = dict(tv.vector or {})
    for mood in unique_moods:
        vector[f"mood_{mood}"] = 0.5
    tv.vector = vector
    await db.commit()
    return {"ok": True, "count": len(unique_moods)}


@router.get(
    "/users/search",
    summary="Search public users",
    description="Searches public user profiles while excluding the current user and blocked relationships.",
)
async def search_users(
    q: str = Query(default=""),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    q = q.strip().lower()
    if len(q) < 2:
        return {"users": []}

    blocked_ids = await get_blocked_ids_for_user(db, current_user.id)
    result = await db.execute(
        select(User).where(
            User.id != current_user.id,
            User.is_public == True,
            User.id.notin_(blocked_ids) if blocked_ids else true(),
            or_(User.username.ilike(f"%{q}%"), User.display_name.ilike(f"%{q}%")),
        )
    )
    users = result.scalars().all()
    user_ids = [user.id for user in users]
    friendship_map: dict[int, tuple[bool, str]] = {}
    if user_ids:
        friendships = (
            await db.execute(
                select(Friend).where(
                    or_(
                        and_(
                            Friend.requester_id == current_user.id,
                            Friend.addressee_id.in_(user_ids),
                        ),
                        and_(
                            Friend.addressee_id == current_user.id,
                            Friend.requester_id.in_(user_ids),
                        ),
                    )
                )
            )
        ).scalars().all()
        for friendship in friendships:
            other_id = (
                friendship.addressee_id
                if friendship.requester_id == current_user.id
                else friendship.requester_id
            )
            status = "none"
            if friendship.status == FriendStatus.accepted:
                status = "accepted"
            elif friendship.requester_id == current_user.id:
                status = "outgoing_pending"
            else:
                status = "incoming_pending"
            friendship_map[other_id] = (
                friendship.status == FriendStatus.accepted,
                status,
            )

    ranked = sorted(
        (
            {
                "id": user.id,
                "username": user.username,
                "display_name": user.display_name,
                "avatar_url": user.avatar_url,
                "city": user.city,
                "updated_at": user.updated_at.isoformat() if user.updated_at else None,
                "is_friend": friendship_map.get(user.id, (False, "none"))[0],
                "friend_request_status": friendship_map.get(user.id, (False, "none"))[1],
                "score": _score_user_match(q, user),
            }
            for user in users
        ),
        key=lambda item: item["score"],
        reverse=True,
    )
    return {
        "users": [
            {k: v for k, v in item.items() if k != "score"}
            for item in ranked[:limit]
            if item["score"] > 0
        ]
    }


@router.get(
    "/users/{user_id}/summary",
    summary="Get social profile summary",
    description="Returns a public-facing social profile summary with relationship state, visible playlists, and recent listening when allowed.",
)
async def get_user_summary(
    user_id: int,
    playlist_limit: int = Query(default=8, ge=1, le=20),
    tracks_limit: int = Query(default=8, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.id != current_user.id and user.id in await get_blocked_ids_for_user(db, current_user.id):
        raise HTTPException(status_code=404, detail="User not found")

    is_self = user.id == current_user.id
    is_friend = is_self or await are_friends(db, current_user.id, user.id)
    if not is_self and not user.is_public and not is_friend:
        raise HTTPException(status_code=404, detail="User not found")

    genres_rows = (
        await db.execute(select(UserGenre.genre).where(UserGenre.user_id == user.id))
    ).scalars().all()
    moods_rows = (
        await db.execute(select(UserMood.mood).where(UserMood.user_id == user.id))
    ).scalars().all()

    followers_count: int | None = None
    following_count: int | None = None
    if is_self or getattr(user, "show_followers", True):
        followers_count = int(
            await db.scalar(
                select(func.count(UserFollow.id)).where(
                    UserFollow.following_id == user.id
                )
            )
            or 0
        )
        following_count = int(
            await db.scalar(
                select(func.count(UserFollow.id)).where(
                    UserFollow.follower_id == user.id
                )
            )
            or 0
        )

    is_following = False
    is_followed_by = False
    if not is_self:
        is_following = (
            await db.scalar(
                select(UserFollow.id).where(
                    UserFollow.follower_id == current_user.id,
                    UserFollow.following_id == user.id,
                )
            )
            is not None
        )
        is_followed_by = (
            await db.scalar(
                select(UserFollow.id).where(
                    UserFollow.follower_id == user.id,
                    UserFollow.following_id == current_user.id,
                )
            )
            is not None
        )

    friendship = None
    if not is_self:
        friendship = await db.scalar(
            select(Friend).where(
                or_(
                    and_(
                        Friend.requester_id == current_user.id,
                        Friend.addressee_id == user.id,
                    ),
                    and_(
                        Friend.requester_id == user.id,
                        Friend.addressee_id == current_user.id,
                    ),
                )
            )
        )

    friend_request_status = "none"
    if friendship:
        if friendship.status == FriendStatus.accepted:
            friend_request_status = "accepted"
        elif friendship.requester_id == current_user.id:
            friend_request_status = "outgoing_pending"
        else:
            friend_request_status = "incoming_pending"

    match = None
    direct_chat = None
    if not is_self:
        match = await db.scalar(
            select(Match).where(
                or_(
                    and_(Match.user_a_id == current_user.id, Match.user_b_id == user.id),
                    and_(Match.user_a_id == user.id, Match.user_b_id == current_user.id),
                )
            )
        )
        direct_chat = await db.scalar(
            select(Chat).where(
                Chat.match_id.is_(None),
                or_(
                    and_(Chat.user_a_id == current_user.id, Chat.user_b_id == user.id),
                    and_(Chat.user_a_id == user.id, Chat.user_b_id == current_user.id),
                ),
            )
        )

    playlist_counts = {"public": 0, "friends": 0, "private": 0}
    playlist_count_rows = (
        await db.execute(
            select(Playlist.visibility, func.count(Playlist.id))
            .where(Playlist.owner_id == user.id)
            .group_by(Playlist.visibility)
        )
    ).all()
    for visibility, count in playlist_count_rows:
        key = visibility.value if hasattr(visibility, "value") else str(visibility)
        playlist_counts[key] = int(count or 0)

    if is_self:
        playlist_visibility_clause = true()
    elif is_friend:
        playlist_visibility_clause = or_(
            Playlist.visibility == PlaylistVisibility.public,
            Playlist.visibility == PlaylistVisibility.friends,
            Playlist.collab_user_id == current_user.id,
        )
    else:
        playlist_visibility_clause = or_(
            Playlist.visibility == PlaylistVisibility.public,
            Playlist.collab_user_id == current_user.id,
        )

    playlist_rows = (
        await db.execute(
            select(Playlist, func.count(PlaylistTrack.id))
            .outerjoin(PlaylistTrack, PlaylistTrack.playlist_id == Playlist.id)
            .where(Playlist.owner_id == user.id, playlist_visibility_clause)
            .group_by(Playlist.id)
            .order_by(Playlist.updated_at.desc(), Playlist.created_at.desc())
            .limit(playlist_limit)
        )
    ).all()

    playlists = [
        {
            "id": playlist.id,
            "owner_id": playlist.owner_id,
            "title": playlist.title,
            "description": playlist.description,
            "cover_url": playlist.cover_url,
            "visibility": playlist.visibility.value,
            "is_collaborative": playlist.is_collaborative,
            "track_count": int(track_count or 0),
            "created_at": playlist.created_at.isoformat(),
            "updated_at": playlist.updated_at.isoformat(),
        }
        for playlist, track_count in playlist_rows
    ]

    can_see_recent = is_self or getattr(user, "show_recently_played", True)
    recent_tracks: list[dict[str, object]] = []
    if can_see_recent:
        recent_rows = (
            await db.execute(
                select(ListeningHistory, TrackCache)
                .join(
                    TrackCache,
                    TrackCache.spotify_id == ListeningHistory.spotify_track_id,
                    isouter=True,
                )
                .where(ListeningHistory.user_id == user.id)
                .order_by(ListeningHistory.created_at.desc())
                .limit(tracks_limit)
            )
        ).all()

        recent_tracks = [
            {
                "spotify_id": history.spotify_track_id,
                "title": track.title if track and track.title else "Unknown track",
                "artist": track.artist if track and track.artist else "",
                "cover_url": track.cover_url if track else None,
                "preview_url": track.preview_url if track else None,
                "played_at": history.created_at.isoformat(),
                "action": history.action.value,
            }
            for history, track in recent_rows
        ]

    favorite_artists = await _followed_artist_profiles(user.id, db)

    return {
        "user": _public_profile_payload(
            user,
            genres=list(genres_rows),
            moods=list(moods_rows),
            followers_count=followers_count,
            following_count=following_count,
        ),
        "relation": {
            "is_self": is_self,
            "is_following": is_following,
            "is_followed_by": is_followed_by,
            "is_friend": is_friend and not is_self,
            "friend_request_status": friend_request_status,
            "can_message": not is_self,
            "match_id": match.id if match else None,
            "similarity_pct": match.similarity_pct if match else None,
            "chat_id": direct_chat.id if direct_chat else None,
        },
        "playlist_stats": {
            **playlist_counts,
            "visible_count": len(playlists),
            "hidden_private_count": max(
                0,
                playlist_counts["private"]
                - sum(
                    1
                    for item in playlists
                    if item["visibility"] == PlaylistVisibility.private.value
                ),
            ),
        },
        "playlists": playlists,
        "recent_tracks": recent_tracks,
        "favorite_artists": favorite_artists,
    }


@router.get(
    "/users/{user_id}",
    response_model=UserResponse,
    summary="Get user profile",
    description="Returns another user's profile when it is visible to the requester and not blocked.",
)
async def get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id != current_user.id and user.id in await get_blocked_ids_for_user(db, current_user.id):
        raise HTTPException(status_code=404, detail="User not found")
    if user.id != current_user.id and not user.is_public:
        if not await are_friends(db, current_user.id, user.id):
            raise HTTPException(status_code=404, detail="User not found")

    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == user.id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == user.id))).scalars().all()
    return _serialize_user(user, genres, moods)


@router.delete(
    "/users/me",
    status_code=200,
    summary="Delete current account",
    description="Permanently deletes the user account and all associated data. Required by app stores.",
)
async def delete_account(
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    email = current_user.email
    first_name = current_user.first_name or ""

    owned_rooms = (
        await db.execute(select(ListeningRoom).where(ListeningRoom.host_id == current_user.id))
    ).scalars().all()
    for room in owned_rooms:
        room.is_active = False
        room.closed_at = datetime.utcnow()

    room_participants = (
        await db.execute(select(RoomParticipant).where(RoomParticipant.user_id == current_user.id))
    ).scalars().all()
    for participant in room_participants:
        participant.status = RoomParticipantStatus.disconnected
        participant.left_at = datetime.utcnow()

    await cache_svc.invalidate_search_results_for_users(redis, [current_user.id])
    await cache_svc.invalidate_match_candidates(redis, [current_user.id])
    await cache_svc.invalidate_recommendations(redis, current_user.id)
    await redis.delete(
        f"taste_vector:{current_user.id}",
        f"now_playing:{current_user.id}",
        f"match_candidates:{current_user.id}",
    )
    await db.delete(current_user)
    await db.commit()
    background_tasks.add_task(send_account_deletion_email, email, first_name, 0)
    return {"message": "account deleted"}


@router.post(
    "/users/me/deactivate",
    summary="Deactivate account for 30 days",
    description="Hides the account for 30 days. Logging back in before the deadline fully restores it.",
)
async def deactivate_account(
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = datetime.utcnow()
    current_user.is_active = False
    current_user.deactivated_at = now
    current_user.delete_at = now + timedelta(days=30)
    current_user.deletion_type = "deactivated_30"
    await db.commit()

    redis = request.app.state.redis
    await cache_svc.invalidate_search_results_for_users(redis, [current_user.id])
    await cache_svc.invalidate_match_candidates(redis, [current_user.id])
    await redis.delete(
        f"taste_vector:{current_user.id}",
        f"now_playing:{current_user.id}",
        f"match_candidates:{current_user.id}",
    )
    background_tasks.add_task(
        send_account_deletion_email, current_user.email, current_user.first_name or "", 30
    )
    return {
        "message": "Account deactivated",
        "will_be_deleted_at": current_user.delete_at.isoformat(),
        "restore_info": "Log in before 30 days to restore your account",
    }


def _week_start_for(value: date | datetime) -> date:
    dt = value.date() if isinstance(value, datetime) else value
    return dt - timedelta(days=dt.weekday())


def _format_week_range_ru(start: date, end: date) -> str:
    if start.month == end.month:
        return f"{RU_MONTHS_SHORT[end.month]} {start.day}–{end.day}"
    return f"{RU_MONTHS_SHORT[start.month]} {start.day} – {RU_MONTHS_SHORT[end.month]} {end.day}"


def _translate_day_part_ru(day_part: str) -> str:
    mapping = {
        "morning": "morning",
        "afternoon": "afternoon",
        "evening": "evening",
        "night": "night",
    }
    return mapping.get(day_part, day_part)


def _build_weekly_insight_ru(
    *,
    total_plays: int,
    unique_artists: int,
    unique_tracks: int,
    top_artist_name: str | None,
    top_artist_plays: int,
    day_parts: dict[str, int],
) -> dict[str, str]:
    if total_plays <= 0:
        return {
            "kind": "empty",
            "title": "Not enough listening data yet",
            "subtitle": "Play a few more tracks and come back to see your weekly recap.",
        }

    dominant_day_part = max(day_parts.items(), key=lambda item: item[1])
    dominant_pct = round((dominant_day_part[1] / total_plays) * 100) if total_plays else 0

    if dominant_pct >= 55 and dominant_day_part[1] > 0:
        return {
            "kind": "dominant_day_part",
            "title": f"{dominant_pct}% of your listening happened in the {_translate_day_part_ru(dominant_day_part[0])}",
            "subtitle": f"The {_translate_day_part_ru(dominant_day_part[0])} clearly dominated this stretch.",
        }

    if top_artist_name and top_artist_plays >= max(2, round(total_plays * 0.45)):
        return {
            "kind": "artist_focus",
            "title": f"{top_artist_name} defined your week",
            "subtitle": f"{top_artist_plays} of your {total_plays} plays came from {top_artist_name}.",
        }

    if unique_artists <= 3:
        noun = "artist" if unique_artists == 1 else "artists"
        return {
            "kind": "tight_rotation",
            "title": f"You stayed close to {unique_artists} {noun}",
            "subtitle": "This week felt tighter and more focused than usual.",
        }

    return {
        "kind": "wide_rotation",
        "title": f"{unique_tracks} tracks shaped this week",
        "subtitle": f"You moved across {unique_artists} artists, so the week felt broader and more exploratory.",
    }


@router.get(
    "/users/me/stats",
    summary="Get profile stats",
    description="Returns listening, monthly activity, top artists and friend-count statistics for the authenticated user.",
)
async def get_me_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    period: str = Query(default="all_time"),
):
    from sqlalchemy import desc as sa_desc

    month_start = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    year_start = datetime.utcnow().replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
    week_start_dt = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    week_start_dt = week_start_dt - timedelta(days=week_start_dt.weekday())

    if period == "month":
        date_from = month_start
    elif period == "week":
        date_from = week_start_dt
    else:
        date_from = None

    base_filter = [ListeningHistory.user_id == current_user.id]
    if date_from is not None:
        base_filter.append(ListeningHistory.created_at >= date_from)

    songs_count = await db.scalar(
        select(func.count(ListeningHistory.id)).where(*base_filter)
    )
    this_month_count = await db.scalar(
        select(func.count(ListeningHistory.id)).where(
            ListeningHistory.user_id == current_user.id,
            ListeningHistory.created_at >= month_start,
        )
    )
    friends_count = await db.scalar(
        select(func.count(Friend.id)).where(
            or_(Friend.requester_id == current_user.id, Friend.addressee_id == current_user.id),
            Friend.status == FriendStatus.accepted,
        )
    )
    followers_count = await db.scalar(
        select(func.count(UserFollow.id)).where(UserFollow.following_id == current_user.id)
    )
    following_count = await db.scalar(
        select(func.count(UserFollow.id)).where(UserFollow.follower_id == current_user.id)
    ) or 0
    artist_following_count = await db.scalar(
        select(func.count(ArtistFollow.id)).where(ArtistFollow.user_id == current_user.id)
    ) or 0
    following_count += artist_following_count
    # Unique artists from listening history
    unique_artists_q = (
        select(func.count(func.distinct(TrackCache.artist)))
        .join(ListeningHistory, ListeningHistory.spotify_track_id == TrackCache.spotify_id)
        .where(*base_filter)
        .where(TrackCache.artist.isnot(None))
        .where(TrackCache.artist != "")
    )
    unique_artists_count = await db.scalar(unique_artists_q)
    # Playlists created — owner_id is the correct column name
    playlists_count = await db.scalar(
        select(func.count(Playlist.id)).where(Playlist.owner_id == current_user.id)
    )
    # Total listening time (sum of track durations)
    time_filter = base_filter if date_from is not None else [
        ListeningHistory.user_id == current_user.id,
        ListeningHistory.created_at >= year_start,
    ]
    total_ms = await db.scalar(
        select(func.sum(TrackCache.duration_ms))
        .join(ListeningHistory, ListeningHistory.spotify_track_id == TrackCache.spotify_id)
        .where(*time_filter)
        .where(TrackCache.duration_ms.isnot(None))
    )
    total_hours = round((total_ms or 0) / 3_600_000, 1)
    # Top 10 artists by play count
    top_artists_rows = (await db.execute(
        select(TrackCache.artist, func.count(ListeningHistory.id).label("plays"))
        .join(ListeningHistory, ListeningHistory.spotify_track_id == TrackCache.spotify_id)
        .where(*base_filter)
        .where(TrackCache.artist.isnot(None))
        .where(TrackCache.artist != "")
        .group_by(TrackCache.artist)
        .order_by(sa_desc("plays"))
        .limit(10)
    )).all()
    top_artists = [{"name": r.artist, "plays": r.plays} for r in top_artists_rows]
    # Top 10 tracks by play count
    top_tracks_rows = (await db.execute(
        select(
            TrackCache.title,
            TrackCache.artist,
            TrackCache.cover_url,
            func.count(ListeningHistory.id).label("plays"),
        )
        .join(ListeningHistory, ListeningHistory.spotify_track_id == TrackCache.spotify_id)
        .where(*base_filter)
        .where(TrackCache.title.isnot(None))
        .group_by(TrackCache.title, TrackCache.artist, TrackCache.cover_url)
        .order_by(sa_desc("plays"))
        .limit(10)
    )).all()
    top_tracks = [
        {"title": r.title, "artist": r.artist, "cover_url": r.cover_url, "play_count": r.plays}
        for r in top_tracks_rows
    ]
    # User genre preferences
    genres = (await db.execute(
        select(UserGenre.genre).where(UserGenre.user_id == current_user.id).limit(5)
    )).scalars().all()
    # Real genre counts from listening history (JSONB unnest)
    from sqlalchemy import text as sa_text
    date_clause = "AND lh.created_at >= :date_from" if date_from is not None else ""
    genre_counts_rows = (await db.execute(sa_text(f"""
        SELECT genre_val, COUNT(*) AS plays
        FROM listening_history lh
        JOIN track_cache tc ON lh.spotify_track_id = tc.spotify_id,
             jsonb_array_elements_text(tc.genres) AS genre_val
        WHERE lh.user_id = :uid
          {date_clause}
          AND jsonb_typeof(tc.genres) = 'array'
          AND genre_val <> ''
        GROUP BY genre_val
        ORDER BY plays DESC
        LIMIT 8
    """), {"uid": current_user.id, "date_from": date_from})).all()
    genre_counts = [{"name": r.genre_val, "plays": r.plays} for r in genre_counts_rows]
    # Listening by time of day
    listening_time_rows = (await db.execute(sa_text(f"""
        SELECT
            CASE
                WHEN EXTRACT(HOUR FROM created_at) BETWEEN 6 AND 11 THEN 'morning'
                WHEN EXTRACT(HOUR FROM created_at) BETWEEN 12 AND 17 THEN 'afternoon'
                WHEN EXTRACT(HOUR FROM created_at) BETWEEN 18 AND 23 THEN 'evening'
                ELSE 'night'
            END AS period,
            COUNT(*) AS plays
        FROM listening_history
        WHERE user_id = :uid
        {date_clause}
        GROUP BY period
    """), {"uid": current_user.id, "date_from": date_from})).all()
    listening_by_time = {"morning": 0, "afternoon": 0, "evening": 0, "night": 0}
    for r in listening_time_rows:
        listening_by_time[r.period] = r.plays
    # Listening streak (consecutive days)
    streak_rows = (await db.execute(sa_text("""
        SELECT DISTINCT DATE(created_at) AS day
        FROM listening_history
        WHERE user_id = :uid
        ORDER BY day DESC
    """), {"uid": current_user.id})).all()
    streak_days = [r.day for r in streak_rows]
    current_streak = 0
    best_streak = 0
    if streak_days:
        today = date.today()
        cur = 0
        prev = None
        for d in streak_days:
            if prev is None:
                if d >= today - timedelta(days=1):
                    cur = 1
                else:
                    cur = 0
            elif (prev - d).days == 1:
                cur += 1
            else:
                best_streak = max(best_streak, cur)
                cur = 1
            prev = d
        best_streak = max(best_streak, cur)
        if streak_days and streak_days[0] >= today - timedelta(days=1):
            current_streak = cur
    # Week count
    this_week_count = await db.scalar(
        select(func.count(ListeningHistory.id)).where(
            ListeningHistory.user_id == current_user.id,
            ListeningHistory.created_at >= week_start_dt,
        )
    )

    return {
        "songs_count": songs_count or 0,
        "songs_played_total": songs_count or 0,
        "songs_played_month": this_month_count or 0,
        "songs_played_week": this_week_count or 0,
        "this_month_count": this_month_count or 0,
        "friends_count": friends_count or 0,
        "followers_count": followers_count or 0,
        "following_count": following_count or 0,
        "unique_artists_count": unique_artists_count or 0,
        "playlists_count": playlists_count or 0,
        "total_hours": total_hours,
        "top_artists": top_artists,
        "top_tracks": top_tracks,
        "genres": list(genres),
        "genre_counts": genre_counts,
        "listening_by_time": listening_by_time,
        "current_streak": current_streak,
        "best_streak": best_streak,
        "user_id": current_user.id,
    }


@router.get(
    "/users/me/stats/weekly-recaps",
    summary="Get weekly listening recap sections",
    description="Returns Spotify-style weekly listening recap sections with top artists, top tracks, hero artwork and insight text for the authenticated user.",
)
async def get_weekly_stats_recaps(
    weeks: int = Query(default=6, ge=1, le=12),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from sqlalchemy import desc as sa_desc

    current_week_start = _week_start_for(datetime.utcnow())
    week_starts = [current_week_start - timedelta(days=7 * offset) for offset in range(weeks)]
    oldest_start = week_starts[-1]
    oldest_start_dt = datetime.combine(oldest_start, datetime.min.time())

    rows = (
        await db.execute(
            select(
                ListeningHistory.created_at,
                TrackCache.spotify_id,
                TrackCache.title,
                TrackCache.artist,
                TrackCache.cover_url,
                TrackCache.preview_url,
                TrackCache.duration_ms,
            )
            .join(TrackCache, TrackCache.spotify_id == ListeningHistory.spotify_track_id, isouter=True)
            .where(ListeningHistory.user_id == current_user.id)
            .where(ListeningHistory.created_at >= oldest_start_dt)
            .order_by(sa_desc(ListeningHistory.created_at))
        )
    ).all()

    grouped_events: dict[date, list[dict]] = {week_start: [] for week_start in week_starts}

    for row in rows:
        event_date = row.created_at.date() if isinstance(row.created_at, datetime) else row.created_at
        week_start = _week_start_for(event_date)
        if week_start not in grouped_events:
            continue
        grouped_events[week_start].append(
            {
                "spotify_id": row.spotify_id,
                "title": row.title or "Unknown track",
                "artist": row.artist or "Unknown artist",
                "cover_url": row.cover_url,
                "preview_url": row.preview_url,
                "duration_ms": row.duration_ms,
                "played_at": row.created_at.isoformat() if row.created_at else None,
            }
        )

    sections: list[dict] = []
    for week_start in week_starts:
        week_end = week_start + timedelta(days=6)
        events = grouped_events.get(week_start, [])
        artist_counts: dict[str, int] = defaultdict(int)
        artist_images: dict[str, str | None] = {}
        track_counts: dict[str, int] = defaultdict(int)
        track_payloads: dict[str, dict] = {}
        track_images: dict[str, str | None] = {}
        day_parts = {"morning": 0, "afternoon": 0, "evening": 0, "night": 0}

        for event in events:
            artist = event["artist"] or "Unknown artist"
            title = event["title"] or "Unknown track"
            cover_url = event.get("cover_url")
            artist_counts[artist] += 1
            artist_images.setdefault(artist, cover_url)

            track_key = f"{artist}::{title}"
            track_counts[track_key] += 1
            track_payloads.setdefault(track_key, event)
            track_images.setdefault(track_key, cover_url)

            played_at_raw = event.get("played_at")
            played_at = datetime.fromisoformat(played_at_raw) if played_at_raw else None
            hour = played_at.hour if played_at else 0
            if 6 <= hour <= 11:
                day_parts["morning"] += 1
            elif 12 <= hour <= 17:
                day_parts["afternoon"] += 1
            elif 18 <= hour <= 23:
                day_parts["evening"] += 1
            else:
                day_parts["night"] += 1

        top_artists = sorted(artist_counts.items(), key=lambda item: item[1], reverse=True)
        top_tracks_entries = sorted(track_counts.items(), key=lambda item: item[1], reverse=True)

        top_artist_items = [
            {
                "name": name,
                "plays": plays,
                "image_url": artist_images.get(name),
            }
            for name, plays in top_artists[:10]
        ]

        top_track_items = []
        for track_key, plays in top_tracks_entries[:10]:
            payload = dict(track_payloads.get(track_key, {}))
            top_track_items.append(
                {
                    "title": payload.get("title") or "Unknown track",
                    "artist": payload.get("artist") or "Unknown artist",
                    "plays": plays,
                    "image_url": track_images.get(track_key),
                    "track": payload,
                }
            )

        hero_images: list[str] = []
        for item in top_track_items:
            image_url = item.get("image_url")
            if image_url and image_url not in hero_images:
                hero_images.append(image_url)
            if len(hero_images) >= 4:
                break

        total_plays = len(events)
        unique_artists = len(artist_counts)
        unique_tracks = len(track_counts)
        top_artist = top_artist_items[0] if top_artist_items else None
        top_track = top_track_items[0] if top_track_items else None
        insight = _build_weekly_insight_ru(
            total_plays=total_plays,
            unique_artists=unique_artists,
            unique_tracks=unique_tracks,
            top_artist_name=top_artist["name"] if top_artist else None,
            top_artist_plays=top_artist["plays"] if top_artist else 0,
            day_parts=day_parts,
        )

        sections.append(
            {
                "start_date": week_start.isoformat(),
                "end_date": week_end.isoformat(),
                "range_label": _format_week_range_ru(week_start, week_end),
                "is_current_week": week_start == current_week_start,
                "total_plays": total_plays,
                "unique_artists": unique_artists,
                "unique_tracks": unique_tracks,
                "top_artist": top_artist,
                "top_track": top_track,
                "top_artists": top_artist_items,
                "top_tracks": top_track_items,
                "hero_images": hero_images,
                "insight": insight,
            }
        )

    return {"weeks": sections}


@router.get(
    "/users/me/privacy-settings",
    summary="Get privacy settings",
    description="Returns the current user's privacy settings.",
)
async def get_privacy_settings(
    current_user: User = Depends(get_current_user),
):
    return {
        "is_public": current_user.is_public,
        "show_activity": current_user.show_activity,
        "show_followers": getattr(current_user, "show_followers", True),
        "show_recently_played": getattr(current_user, "show_recently_played", True),
    }


class PrivacySettingsRequest(BaseModel):
    is_public: Optional[bool] = None
    show_activity: Optional[bool] = None
    show_followers: Optional[bool] = None
    show_recently_played: Optional[bool] = None


@router.put(
    "/users/me/privacy-settings",
    summary="Update privacy settings",
    description="Updates the current user's privacy settings.",
)
async def update_privacy_settings(
    body: PrivacySettingsRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = body.model_dump(exclude_none=True)
    for key, value in data.items():
        setattr(current_user, key, value)
    await db.commit()
    return {
        "is_public": current_user.is_public,
        "show_activity": current_user.show_activity,
        "show_followers": getattr(current_user, "show_followers", True),
        "show_recently_played": getattr(current_user, "show_recently_played", True),
    }


_DEFAULT_NOTIF_SETTINGS = {
    "new_follower": True,
    "friend_request": True,
    "match_found": True,
    "room_invite": True,
    "promotions": False,
}


@router.get(
    "/users/me/notification-settings",
    summary="Get notification settings",
    description="Returns the current user's notification preferences.",
)
async def get_notification_settings(
    current_user: User = Depends(get_current_user),
):
    stored = getattr(current_user, "notif_settings_json", None) or {}
    return {**_DEFAULT_NOTIF_SETTINGS, **stored}


class NotificationSettingsRequest(BaseModel):
    new_follower: Optional[bool] = None
    friend_request: Optional[bool] = None
    match_found: Optional[bool] = None
    room_invite: Optional[bool] = None
    promotions: Optional[bool] = None


@router.put(
    "/users/me/notification-settings",
    summary="Update notification settings",
    description="Updates the current user's notification preferences.",
)
async def update_notification_settings(
    body: NotificationSettingsRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = dict(getattr(current_user, "notif_settings_json", None) or {})
    updates = body.model_dump(exclude_none=True)
    existing.update(updates)
    current_user.notif_settings_json = existing
    await db.commit()
    return {**_DEFAULT_NOTIF_SETTINGS, **existing}


@router.post(
    "/users/me/cache-clear",
    summary="Clear user cache",
    description="Clears cached recommendations and taste vector data for the current user.",
)
async def clear_user_cache(
    request: Request,
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    await cache_svc.invalidate_recommendations(redis, current_user.id)
    await redis.delete(
        f"taste_vector:{current_user.id}",
        f"now_playing:{current_user.id}",
        f"match_candidates:{current_user.id}",
    )
    return {"message": "Cache cleared"}


@router.get(
    "/taste-vector/me",
    summary="Get current taste vector",
    description="Returns the authenticated user's raw taste vector along with top genres and top artists.",
)
async def get_taste_vector_me(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    vector = tv.vector if tv and tv.vector else {}

    top_genres = sorted(
        [
            {"name": k.replace("genre:", "").replace("_", " "), "weight": float(v)}
            for k, v in vector.items()
            if k.startswith("genre:") and float(v) > 0
        ],
        key=lambda x: x["weight"],
        reverse=True,
    )[:5]

    top_artists = sorted(
        [
            {"name": k.replace("artist_", "").replace("_", " "), "weight": float(v)}
            for k, v in vector.items()
            if k.startswith("artist_") and float(v) > 0
        ],
        key=lambda x: x["weight"],
        reverse=True,
    )[:5]

    return {
        "vector": vector,
        "top_genres": top_genres,
        "top_artists": top_artists,
    }


# ---------------------------------------------------------------------------
# OAuth helpers
# ---------------------------------------------------------------------------

import re as _re
import secrets as _secrets


async def _get_or_create_oauth_user(
    db: AsyncSession,
    *,
    email: str,
    display_name: str,
    avatar_url: Optional[str] = None,
    phone: Optional[str] = None,
) -> tuple[User, bool]:
    """Find existing user by email/phone or create a new verified one.
    Returns (user, is_new_user)."""
    if email:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
    elif phone:
        result = await db.execute(select(User).where(User.phone == phone))
        user = result.scalar_one_or_none()
    else:
        user = None

    if user:
        if user.deactivated_at:
            user.deactivated_at = None
            user.delete_at = None
            user.deletion_type = None
            await db.commit()
            await db.refresh(user)
        return user, False

    # Generate unique username
    base = _re.sub(r"[^a-z0-9]", "", (email or "").split("@")[0].lower()) or "user"
    if len(base) < 3:
        base = base + "user"
    username = base
    suffix = 0
    while True:
        existing = await db.scalar(select(User).where(User.username == username))
        if not existing:
            break
        suffix += 1
        username = f"{base}{suffix}"

    # Phone-only users get a placeholder email
    final_email = email or f"phone_{phone}@moodwave.internal"

    user = User(
        email=final_email,
        username=username,
        hashed_password=hash_password(_secrets.token_hex(32)),
        display_name=display_name or username,
        avatar_url=avatar_url,
        phone=phone,
        is_verified=True,
        is_active=True,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user, True


async def _build_token_response(user: User, db: AsyncSession, is_new: bool = False) -> TokenResponse:
    access_token = create_access_token(user.id)
    refresh_token_val = create_refresh_token(user.id)
    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == user.id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == user.id))).scalars().all()
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_val,
        user=_serialize_user(user, genres, moods),
        needs_onboarding=True if is_new else None,
    )


# ---------------------------------------------------------------------------
# Google OAuth (via Firebase token)
# ---------------------------------------------------------------------------

class GoogleAuthRequest(BaseModel):
    id_token: str  # Firebase ID token after Google sign-in


@router.post("/auth/google", response_model=TokenResponse, summary="Sign in with Google")
async def google_auth(
    body: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    try:
        from firebase_admin import auth as _fb_auth
        from app.services.firebase_service import init_firebase
        if not init_firebase():
            raise HTTPException(status_code=503, detail="Firebase not configured")
        decoded = _fb_auth.verify_id_token(body.id_token)
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Google/Firebase token verification failed: %s", exc)
        raise HTTPException(status_code=400, detail="Invalid token")

    email = decoded.get("email", "")
    name = decoded.get("name", "")
    avatar = decoded.get("picture")

    user, is_new = await _get_or_create_oauth_user(db, email=email, display_name=name, avatar_url=avatar)
    return await _build_token_response(user, db, is_new=is_new)
