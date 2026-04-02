import logging
import os
from datetime import date, datetime, timedelta
from difflib import SequenceMatcher
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import func, or_, select, true
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

from app.dependencies import get_db, get_current_user
from app.models.rooms import ListeningRoom, RoomParticipant, RoomParticipantStatus
from app.models.music import ListeningHistory
from app.models.social import Friend, FriendStatus
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
from app.services.email_service import (
    send_verification_email, send_reset_email,
    send_account_deletion_email, send_reactivation_email,
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
    gender: Optional[str] = Field(default=None, max_length=20)
    avatar_preset: Optional[int] = Field(default=None, ge=0, le=11)
    banner_preset: Optional[int] = Field(default=None, ge=0, le=5)
    is_public: Optional[bool] = None
    show_activity: Optional[bool] = None


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


def _serialize_user(user: User, genres: list[UserGenre], moods: list[UserMood]) -> UserResponse:
    return UserResponse.model_validate({
        "id": user.id,
        "email": user.email,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "bio": user.bio,
        "birth_date": user.birth_date,
        "city": user.city,
        "gender": user.gender,
        "avatar_preset": getattr(user, "avatar_preset", 0) or 0,
        "banner_preset": getattr(user, "banner_preset", 0) or 0,
        "is_public": user.is_public,
        "show_activity": user.show_activity,
        "is_verified": user.is_verified,
        "is_active": user.is_active,
        "is_admin": getattr(user, "is_admin", False),
        "genres": [item.genre for item in genres],
        "moods": [item.mood for item in moods],
        "created_at": user.created_at,
    })


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

    background_tasks.add_task(
        send_verification_email, user.email, code, user.first_name or ""
    )
    logger.info("====== VERIFICATION CODE for %s: %s ======", user.email, code)
    print(f"====== VERIFICATION CODE for {user.email}: {code} ======", flush=True)

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user=_serialize_user(user, [], []),
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

    background_tasks.add_task(send_verification_email, user.email, code, user.first_name or "")
    logger.info("====== VERIFICATION CODE for %s: %s ======", user.email, code)
    print(f"====== VERIFICATION CODE for {user.email}: {code} ======", flush=True)
    return {"message": "Code sent"}


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
    # Always return 200 to avoid email enumeration
    if user and user.is_active:
        code = generate_code()
        user.reset_code = code
        user.reset_code_expires = datetime.utcnow() + timedelta(minutes=CODE_TTL_MINUTES)
        await db.commit()
        background_tasks.add_task(send_reset_email, user.email, code, user.first_name or "")

    return {"message": "If this email exists, a code was sent", "method": "email"}


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
    return _serialize_user(current_user, genres, moods)


@router.put(
    "/users/me",
    response_model=UserResponse,
    summary="Update current profile",
    description="Updates editable profile fields such as name, bio, city, privacy, and activity visibility.",
)
async def update_me(
    body: UpdateProfileRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = body.model_dump(exclude_none=True)
    if "username" in data and data["username"] != current_user.username:
        existing = await db.scalar(
            select(User).where(User.username == data["username"], User.id != current_user.id)
        )
        if existing:
            raise HTTPException(status_code=400, detail="Username already taken")

    for key, value in data.items():
        setattr(current_user, key, value)
    await db.commit()
    await db.refresh(current_user)
    if {"is_public", "username", "display_name"} & set(data.keys()):
        await cache_svc.invalidate_all_search_results(request.app.state.redis)

    genres = (await db.execute(select(UserGenre).where(UserGenre.user_id == current_user.id))).scalars().all()
    moods = (await db.execute(select(UserMood).where(UserMood.user_id == current_user.id))).scalars().all()
    return _serialize_user(current_user, genres, moods)


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
    for item in body.genres:
        value = item if isinstance(item, str) else item.genre
        normalized = _normalize_genre(value)
        if normalized not in seen:
            seen.add(normalized)
            unique_genres.append(normalized)

    if len(unique_genres) < 3:
        raise HTTPException(status_code=400, detail="Select at least 3 genres")

    invalid = [genre for genre in unique_genres if genre not in ALLOWED_GENRES]
    if invalid:
        raise HTTPException(status_code=400, detail=f"Invalid genre name: {', '.join(invalid)}")

    existing = (
        await db.execute(select(UserGenre).where(UserGenre.user_id == current_user.id))
    ).scalars().all()
    existing_map = {row.genre.lower(): row for row in existing}

    for genre in unique_genres:
        if genre in existing_map:
            existing_map[genre].weight = 0.5
        else:
            db.add(UserGenre(user_id=current_user.id, genre=genre, weight=0.5))

    tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    if not tv:
        tv = TasteVector(user_id=current_user.id, vector={})
        db.add(tv)
    vector = dict(tv.vector or {})
    for genre in unique_genres:
        vector[f"genre:{genre.replace(' ', '_')}"] = 0.5
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

    ranked = sorted(
        (
            {
                "id": user.id,
                "username": user.username,
                "display_name": user.display_name,
                "avatar_url": user.avatar_url,
                "city": user.city,
                "score": _score_user_match(q, user),
            }
            for user in result.scalars().all()
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


@router.get(
    "/users/me/stats",
    summary="Get profile stats",
    description="Returns listening, monthly activity, and friend-count statistics for the authenticated user.",
)
async def get_me_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    songs_count = await db.scalar(
        select(func.count(ListeningHistory.id)).where(ListeningHistory.user_id == current_user.id)
    )
    month_start = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
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
    return {
        "songs_count": songs_count or 0,
        "this_month_count": this_month_count or 0,
        "friends_count": friends_count or 0,
    }


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
# Debug — only available in development
# ---------------------------------------------------------------------------

@router.get(
    "/auth/debug-code",
    summary="[DEV] Get current verification code",
    description="Returns the current verification code for testing. Only works when APP_ENV=development.",
)
async def debug_get_code(
    email: str = Query(),
    db: AsyncSession = Depends(get_db),
):
    if os.getenv("APP_ENV", "development") != "development":
        raise HTTPException(status_code=404, detail="Not found")
    user = await db.scalar(select(User).where(User.email == email))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "email": user.email,
        "verification_code": user.verification_code,
        "is_verified": user.is_verified,
        "code_expires": user.verification_code_expires.isoformat() if user.verification_code_expires else None,
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
) -> User:
    """Find existing user by email/phone or create a new verified one."""
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
        return user

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
    return user


def _build_token_response(user: User) -> TokenResponse:
    access_token = create_access_token({"sub": str(user.id)})
    refresh_token_val = create_refresh_token({"sub": str(user.id)})
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_val,
        user=UserResponse.model_validate(user),
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

    user = await _get_or_create_oauth_user(db, email=email, display_name=name, avatar_url=avatar)
    return _build_token_response(user)


# ---------------------------------------------------------------------------
# Firebase Phone Auth
# ---------------------------------------------------------------------------

class FirebasePhoneRequest(BaseModel):
    firebase_token: str


@router.post("/auth/firebase-phone", response_model=TokenResponse, summary="Sign in with phone (Firebase)")
async def firebase_phone_auth(
    body: FirebasePhoneRequest,
    db: AsyncSession = Depends(get_db),
):
    try:
        from firebase_admin import auth as _fb_auth
        from app.services.firebase_service import init_firebase
        if not init_firebase():
            raise HTTPException(status_code=503, detail="Firebase not configured")
        decoded = _fb_auth.verify_id_token(body.firebase_token)
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Firebase token verification failed: %s", exc)
        raise HTTPException(status_code=400, detail="Invalid Firebase token")

    phone = decoded.get("phone_number")
    if not phone:
        raise HTTPException(status_code=400, detail="Token has no phone number")

    user = await _get_or_create_oauth_user(db, email="", display_name="", phone=phone)
    return _build_token_response(user)
