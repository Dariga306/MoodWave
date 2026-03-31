from __future__ import annotations
import os

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.social import MatchDecision
from app.models.user import TasteVector, User, UserGenre
from app.services import cache as cache_svc

router = APIRouter()

_DEMO_GENRES = ["Pop", "Indie Rock", "Alt Pop", "Electronic", "R&B"]
_DEMO_VECTOR = {
    "genre:pop": 0.8,
    "genre:indie_rock": 0.75,
    "genre:alt_pop": 0.7,
    "genre:electronic": 0.6,
    "genre:r_b": 0.65,
    "mood_late_night": 0.8,
    "mood_study": 0.5,
    "mood_chill": 0.7,
}
_DEMO_USERS = [
    {"first_name": "Daniyar", "prefix": "demo_daniyar", "city": "Astana"},
    {"first_name": "Madi", "prefix": "demo_madi", "city": "Almaty"},
    {"first_name": "Arman", "prefix": "demo_arman", "city": "Astana"},
]
# Not a real bcrypt hash — demo users cannot log in
_DEMO_PW_HASH = "$2b$12$demo0000000000000000000000000000000000000000000000000"


@router.post(
    "/debug/seed-demo-match",
    summary="[DEV] Seed demo match users",
    description=(
        "Creates 3 demo users (Daniyar, Madi, Arman) that have already liked you. "
        "Open the Match tab and swipe right to create mutual matches and chats. "
        "Development only (APP_ENV=development)."
    ),
)
async def seed_demo_match(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if os.getenv("APP_ENV", "development") != "development":
        raise HTTPException(status_code=404, detail="Not found")

    # Ensure current user has a taste vector (match candidates won't show without one)
    my_tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    if not my_tv:
        genre_rows = (
            await db.execute(select(UserGenre).where(UserGenre.user_id == current_user.id))
        ).scalars().all()
        vector: dict = {}
        for row in genre_rows:
            key = (
                "genre:"
                + row.genre.lower()
                .replace(" ", "_")
                .replace("&", "")
                .replace("-", "_")
                .strip("_")
            )
            vector[key] = float(row.weight)
        if not vector:
            vector = dict(_DEMO_VECTOR)
        db.add(TasteVector(user_id=current_user.id, vector=vector))
        await db.flush()

    results = []
    for demo in _DEMO_USERS:
        suffix = str(current_user.id)
        username = f"{demo['prefix']}_{suffix}"
        email = f"{username}@demo.moodwave.app"

        demo_user = await db.scalar(select(User).where(User.username == username))
        if not demo_user:
            demo_user = User(
                email=email,
                username=username,
                hashed_password=_DEMO_PW_HASH,
                first_name=demo["first_name"],
                display_name=demo["first_name"],
                city=demo["city"],
                is_verified=True,
                is_active=True,
            )
            db.add(demo_user)
            await db.flush()

            for genre in _DEMO_GENRES:
                db.add(UserGenre(user_id=demo_user.id, genre=genre, weight=1.0))

            db.add(TasteVector(user_id=demo_user.id, vector=dict(_DEMO_VECTOR)))
            await db.flush()

        # Remove any previous decision current_user made about this demo user
        # so the demo user shows up in match candidates again
        my_dec = await db.scalar(
            select(MatchDecision).where(
                MatchDecision.user_id == current_user.id,
                MatchDecision.target_user_id == demo_user.id,
            )
        )
        if my_dec:
            await db.delete(my_dec)
            await db.flush()

        # Ensure demo_user already liked current_user (pre-like)
        existing_like = await db.scalar(
            select(MatchDecision).where(
                MatchDecision.user_id == demo_user.id,
                MatchDecision.target_user_id == current_user.id,
            )
        )
        if existing_like:
            if existing_like.decision != "like":
                existing_like.decision = "like"
                existing_like.hidden_until = None
            status = "already_liked"
        else:
            db.add(
                MatchDecision(
                    user_id=demo_user.id,
                    target_user_id=current_user.id,
                    decision="like",
                )
            )
            status = "ready"

        results.append(
            {
                "first_name": demo["first_name"],
                "username": username,
                "city": demo["city"],
                "status": status,
            }
        )

    await db.commit()
    await cache_svc.invalidate_match_candidates(request.app.state.redis, [current_user.id])

    return {
        "message": "Demo users seeded! Open the Match tab and swipe right to create mutual matches + chats.",
        "users": results,
        "instructions": [
            "1. Open the Match tab in the app",
            "2. Swipe right (like) on Daniyar, Madi, and Arman",
            "3. A mutual match dialog appears — tap 'Start Chat'",
            "4. Send messages and test the chat flow",
        ],
    }
