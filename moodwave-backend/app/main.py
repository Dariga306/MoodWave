import logging
from contextlib import asynccontextmanager
import asyncio
from datetime import datetime, timedelta
from pathlib import Path

import redis.asyncio as aioredis
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from sqlalchemy import delete, text

from app.config import settings
from app.database import AsyncSessionLocal, Base, engine
from app.models.music import ListeningHistory
from app.routers import auth, music, weather, match, chat, social, rooms, playlists, search, charts, debug, admin, radio, trending, moods
from app.services import firebase as firebase_svc
from app.services.matching import recalculate_all_vectors
from app.services.email_service import send_account_deletion_email

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

limiter = Limiter(key_func=get_remote_address)
scheduler = AsyncIOScheduler()
UPLOADS_DIR = Path(__file__).resolve().parents[1] / "uploads"
LISTENING_HISTORY_TTL_DAYS = 60


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    app.state.redis = await aioredis.from_url(
        settings.REDIS_URL,
        decode_responses=True,
        socket_connect_timeout=2,
        socket_timeout=2,
    )
    app.state.firebase_ready = firebase_svc.init_firebase()
    app.state.limiter = limiter
    if not scheduler.running:
        scheduler.add_job(
            func=lambda: asyncio.create_task(_run_daily_recalculate(app)),
            trigger=CronTrigger(hour=3, minute=0),
            id="daily_taste_vector_recalculate",
            replace_existing=True,
        )
        scheduler.add_job(
            func=lambda: asyncio.create_task(_run_auto_delete(app)),
            trigger=CronTrigger(minute=0),  # every hour
            id="auto_delete_expired_accounts",
            replace_existing=True,
        )
        scheduler.add_job(
            func=lambda: asyncio.create_task(_run_history_cleanup()),
            trigger=CronTrigger(minute=15),
            id="cleanup_old_listening_history",
            replace_existing=True,
        )
        scheduler.add_job(
            func=lambda: asyncio.create_task(_run_trending_cleanup(app)),
            trigger=CronTrigger(hour=3, minute=30),
            id="trending_cleanup",
            replace_existing=True,
        )
        scheduler.add_job(
            func=lambda: asyncio.create_task(_run_trending_trim(app)),
            trigger=CronTrigger(minute=30),
            id="trending_trim",
            replace_existing=True,
        )
        scheduler.start()
    await _run_history_cleanup()
    logger.info("MoodWave API started (firebase_ready=%s)", app.state.firebase_ready)
    yield
    # Shutdown
    if scheduler.running:
        scheduler.shutdown(wait=False)
    await app.state.redis.aclose()
    await engine.dispose()
    logger.info("MoodWave API stopped")


async def _run_daily_recalculate(app: FastAPI) -> None:
    async with AsyncSessionLocal() as session:
        await recalculate_all_vectors(session, app.state.redis)


async def _run_auto_delete(app: FastAPI) -> None:
    """Permanently delete accounts whose 30-day deactivation grace period has expired."""
    from datetime import datetime
    from sqlalchemy import select, and_
    from app.models.user import User
    from app.models.rooms import ListeningRoom, RoomParticipant, RoomParticipantStatus

    async with AsyncSessionLocal() as db:
        now = datetime.utcnow()
        expired = (
            await db.execute(
                select(User).where(
                    and_(
                        User.deletion_type == "deactivated_30",
                        User.is_active == False,  # noqa: E712
                        User.delete_at <= now,
                    )
                )
            )
        ).scalars().all()

        if not expired:
            return

        redis = app.state.redis
        for user in expired:
            email, first_name = user.email, user.first_name or ""
            try:
                owned = (
                    await db.execute(
                        select(ListeningRoom).where(ListeningRoom.host_id == user.id)
                    )
                ).scalars().all()
                for room in owned:
                    room.is_active = False
                    room.closed_at = now

                parts = (
                    await db.execute(
                        select(RoomParticipant).where(RoomParticipant.user_id == user.id)
                    )
                ).scalars().all()
                for p in parts:
                    p.status = RoomParticipantStatus.disconnected
                    p.left_at = now

                await db.delete(user)
                await db.commit()
                await redis.delete(
                    f"taste_vector:{user.id}",
                    f"now_playing:{user.id}",
                    f"match_candidates:{user.id}",
                )
                await send_account_deletion_email(email, first_name, 0)
                logger.info("Auto-deleted expired account: %s", email)
            except Exception as exc:
                logger.error("Failed to auto-delete account %s: %s", email, exc)
                await db.rollback()

        logger.info("Auto-delete job: processed %d expired accounts", len(expired))


async def _run_trending_cleanup(app: FastAPI) -> None:
    """Remove tracks with score < 5 from trending sets to keep them fresh."""
    redis = app.state.redis
    await redis.zremrangebyscore("trending:global", "-inf", 4)


async def _run_trending_trim(app: FastAPI) -> None:
    """Every 30 min: trim trending sets to top 100."""
    redis = app.state.redis
    await redis.zremrangebyrank("trending:global", 0, -101)


async def _run_history_cleanup() -> None:
    cutoff = datetime.utcnow() - timedelta(days=LISTENING_HISTORY_TTL_DAYS)
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            delete(ListeningHistory).where(ListeningHistory.created_at < cutoff)
        )
        await db.commit()
        deleted_count = result.rowcount or 0
        if deleted_count:
            logger.info("Listening history cleanup removed %d records older than %d days", deleted_count, LISTENING_HISTORY_TTL_DAYS)


app = FastAPI(
    title="MoodWave API",
    version="1.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5001",
        "http://127.0.0.1:5001",
        "http://localhost:5002",
        "http://127.0.0.1:5002",
        "http://localhost:5004",
        "http://127.0.0.1:5004",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_origin_regex=(
        r"https?://("
        r"localhost|"
        r"127\.0\.0\.1|"
        r"0\.0\.0\.0|"
        r"10\.\d+\.\d+\.\d+|"
        r"192\.168\.\d+\.\d+|"
        r"172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+"
        r")(:\d+)?$"
    ),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

app.include_router(auth.router, tags=["auth"])
app.include_router(music.router, prefix="/tracks", tags=["music"])
app.include_router(music.artist_router, tags=["artists"])
app.include_router(music.album_router, tags=["albums"])
app.include_router(weather.router, prefix="/weather", tags=["weather"])
app.include_router(match.router, prefix="/matches", tags=["match"])
app.include_router(chat.router, prefix="/chats", tags=["chat"])
app.include_router(social.router, tags=["social"])
app.include_router(playlists.router, prefix="/playlists", tags=["playlists"])
app.include_router(search.router, prefix="/search", tags=["search"])
app.include_router(charts.router, prefix="/charts", tags=["charts"])
app.include_router(rooms.router, tags=["rooms"])
app.include_router(debug.router, tags=["debug"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])
app.include_router(radio.router, prefix="/radio", tags=["radio"])
app.include_router(trending.router, prefix="/trending", tags=["trending"])
app.include_router(moods.router, prefix="/moods", tags=["moods"])


@app.get(
    "/health",
    summary="Check API health",
    description="Returns service status for the API, PostgreSQL, Redis, and Firebase integrations.",
)
async def health():
    db_status = "disconnected"
    redis_status = "disconnected"
    firebase_status = "disconnected"

    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db_status = "connected"
    except Exception:
        logger.exception("Health check DB failed")

    try:
        if await app.state.redis.ping():
            redis_status = "connected"
    except Exception:
        logger.exception("Health check Redis failed")

    try:
        if firebase_svc.init_firebase():
            firebase_status = "connected"
    except Exception:
        logger.exception("Health check Firebase failed")

    payload = {
        "status": "ok" if all(
            status == "connected" for status in (db_status, redis_status, firebase_status)
        ) else "degraded",
        "version": "1.0.0",
        "db": db_status,
        "redis": redis_status,
        "firebase": firebase_status,
    }
    if payload["status"] != "ok":
        return JSONResponse(status_code=503, content=payload)
    return payload
