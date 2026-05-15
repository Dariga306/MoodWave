import logging
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from pathlib import Path

import redis.asyncio as aioredis
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from sqlalchemy import delete, text

from app.config import settings
from app.database import AsyncSessionLocal, Base, engine
from app.models.music import ListeningHistory
from app.services import firebase as firebase_svc
from app.services import deezer as deezer_service
from app.services.matching import recalculate_all_vectors
from app.services.email_service import send_account_deletion_email

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

limiter = Limiter(key_func=get_remote_address)
UPLOADS_DIR = Path(__file__).resolve().parents[1] / "uploads"

LISTENING_HISTORY_TTL_DAYS = 60


# =========================
# Scheduler setup
# =========================

scheduler = AsyncIOScheduler()


def setup_scheduler(app: FastAPI):
    if scheduler.running:
        return

    scheduler.add_job(_run_daily_recalculate, CronTrigger(hour=3, minute=0), args=[app])
    scheduler.add_job(_run_auto_delete, CronTrigger(minute=0), args=[app])
    scheduler.add_job(_run_history_cleanup, CronTrigger(minute=15))
    scheduler.add_job(_run_trending_cleanup, CronTrigger(hour=3, minute=30), args=[app])
    scheduler.add_job(_run_trending_trim, CronTrigger(minute=30), args=[app])

    scheduler.start()


def shutdown_scheduler():
    if scheduler.running:
        scheduler.shutdown(wait=False)


# =========================
# Lifespan
# =========================

async def _create_redis_client():
    try:
        client = aioredis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        await client.ping()
        logger.info("Connected to Redis at %s", settings.REDIS_URL)
        return client
    except Exception as exc:
        logger.warning(
            "Redis unavailable at %s, using in-memory fakeredis fallback: %s",
            settings.REDIS_URL,
            exc,
        )
        from fakeredis.aioredis import FakeRedis

        return FakeRedis(decode_responses=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
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

    setup_scheduler(app)

    app.state.redis = await _create_redis_client()
    app.state.firebase_ready = firebase_svc.init_firebase()
    app.state.limiter = limiter
    if not scheduler.running:
        scheduler.add_job(
            func=_run_daily_recalculate,
            args=[app],
            trigger=CronTrigger(hour=3, minute=0),
            id="daily_taste_vector_recalculate",
            replace_existing=True,
        )
        scheduler.add_job(
            func=_run_auto_delete,
            args=[app],
            trigger=CronTrigger(minute=0),  # every hour
            id="auto_delete_expired_accounts",
            replace_existing=True,
        )
        scheduler.add_job(
            func=_run_history_cleanup,
            trigger=CronTrigger(minute=15),
            id="cleanup_old_listening_history",
            replace_existing=True,
        )
        scheduler.add_job(
            func=_run_trending_cleanup,
            args=[app],
            trigger=CronTrigger(hour=3, minute=30),
            id="trending_cleanup",
            replace_existing=True,
        )
        scheduler.add_job(
            func=_run_trending_trim,
            args=[app],
            trigger=CronTrigger(minute=30),
            id="trending_trim",
            replace_existing=True,
        )
        scheduler.start()
    await _run_history_cleanup()

    logger.info("API started (firebase=%s)", app.state.firebase_ready)

    yield

    shutdown_scheduler()

    if getattr(app.state, "redis", None):
        await app.state.redis.aclose()

    await engine.dispose()
    await deezer_service.close_client()

    logger.info("API stopped")


# =========================
# Background jobs
# =========================

async def _run_daily_recalculate(app: FastAPI):
    async with AsyncSessionLocal() as session:
        await recalculate_all_vectors(session, app.state.redis)


async def _run_auto_delete(app: FastAPI):
    from sqlalchemy import select, and_
    from app.models.user import User
    from app.models.rooms import ListeningRoom, RoomParticipant, RoomParticipantStatus

    now = datetime.utcnow()

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(User).where(
                and_(
                    User.deletion_type == "deactivated_30",
                    User.is_active == False,
                    User.delete_at <= now,
                )
            )
        )

        users = result.scalars().all()
        if not users:
            return

        redis = app.state.redis

        for user in users:
            try:
                rooms = await db.execute(
                    select(ListeningRoom).where(ListeningRoom.host_id == user.id)
                )

                for room in rooms.scalars():
                    room.is_active = False
                    room.closed_at = now

                parts = await db.execute(
                    select(RoomParticipant).where(RoomParticipant.user_id == user.id)
                )

                for p in parts.scalars():
                    p.status = RoomParticipantStatus.disconnected
                    p.left_at = now

                email, first_name = user.email, user.first_name or ""

                await db.delete(user)
                await db.commit()

                await redis.delete(
                    f"taste_vector:{user.id}",
                    f"now_playing:{user.id}",
                    f"match_candidates:{user.id}",
                )

                await send_account_deletion_email(email, first_name, 0)

            except Exception as e:
                await db.rollback()
                logger.error("Auto-delete failed for %s: %s", user.id, e)


async def _run_history_cleanup():
    cutoff = datetime.utcnow() - timedelta(days=LISTENING_HISTORY_TTL_DAYS)

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            delete(ListeningHistory).where(ListeningHistory.created_at < cutoff)
        )
        await db.commit()

        if result.rowcount:
            logger.info("Deleted %d old listening records", result.rowcount)


async def _run_trending_cleanup(app: FastAPI):
    await app.state.redis.zremrangebyscore("trending:global", "-inf", 4)


async def _run_trending_trim(app: FastAPI):
    await app.state.redis.zremrangebyrank("trending:global", 0, -101)


# =========================
# App init
# =========================

app = FastAPI(
    title="MoodWave API",
    version="1.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, lambda r, e: JSONResponse(
    status_code=429,
    content={"detail": "Rate limit exceeded"},
))

app.add_middleware(GZipMiddleware, minimum_size=1000)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")


# routers (оставил как есть)
from app.routers import (
    auth, music, weather, match, chat, social, rooms,
    playlists, search, charts, debug, admin, radio,
    trending, moods
)

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
app.include_router(admin.router, prefix="/admin", tags=["admin"])
app.include_router(trending.router, prefix="/trending", tags=["trending"])
app.include_router(moods.router, prefix="/moods", tags=["moods"])


@app.get("/health")
async def health():
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db = "connected"
    except:
        db = "disconnected"

    redis = "connected" if await app.state.redis.ping() else "disconnected"
    firebase = "connected" if app.state.firebase_ready else "disconnected"

    status = "ok" if all(x == "connected" for x in (db, redis, firebase)) else "degraded"

    return JSONResponse(
        status_code=200 if status == "ok" else 503,
        content={
            "status": status,
            "db": db,
            "redis": redis,
            "firebase": firebase,
        },
    )
