from __future__ import annotations
import os

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.social import ArtistFollow, MatchDecision
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
    {
        "first_name": "Daniyar",
        "prefix": "demo_daniyar",
        "city": "Astana",
        "bio": "Late-night pop, sleek synths, and replaying one perfect chorus 20 times.",
        "avatar_url": "https://i.pravatar.cc/300?img=12",
        "banner_url": "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80",
        "is_public": True,
        "hide_music_taste": False,
        "show_match_city": True,
        "profile_shift": 0.08,
        "genres": ["Pop", "Alt Pop", "Dream Pop", "R&B", "Electronic"],
        "artist_ids": [12246, 1176900, 5292512],
    },
    {
        "first_name": "Madi",
        "prefix": "demo_madi",
        "city": "Almaty",
        "bio": "Moody indie, headphones on, city lights, and too many favorite bridges.",
        "avatar_url": "https://i.pravatar.cc/300?img=33",
        "banner_url": "https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=1200&q=80",
        "is_public": True,
        "hide_music_taste": False,
        "show_match_city": True,
        "profile_shift": 0.18,
        "genres": ["Indie Rock", "Alt Pop", "Dream Pop", "Electronic", "Pop"],
        "artist_ids": [296861, 3583591, 134790],
    },
    {
        "first_name": "Arman",
        "prefix": "demo_arman",
        "city": "Astana",
        "bio": "Private profile, but the playlist is immaculate.",
        "avatar_url": "https://i.pravatar.cc/300?img=45",
        "banner_url": "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=1200&q=80",
        "is_public": False,
        "hide_music_taste": False,
        "show_match_city": True,
        "profile_shift": 0.28,
        "genres": ["Pop", "Electronic", "R&B", "Synthwave", "Alt Pop"],
        "artist_ids": [12178, 76053262, 4050205],
    },
    {
        "first_name": "Sabina",
        "prefix": "demo_sabina",
        "city": "New York",
        "bio": "Soft vocals, dreamy hooks, and a dangerous amount of Lana Del Rey.",
        "avatar_url": "https://i.pravatar.cc/300?img=47",
        "banner_url": "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=1200&q=80",
        "is_public": True,
        "hide_music_taste": False,
        "show_match_city": True,
        "profile_shift": 0.12,
        "genres": ["Dream Pop", "Alt Pop", "Pop", "Indie Rock", "Trip Hop"],
        "artist_ids": [1424821, 4448485, 1058631],
    },
    {
        "first_name": "Aruzhan",
        "prefix": "demo_aruzhan",
        "city": "London",
        "bio": "Hidden taste on purpose. Match first, then unlock the chaos.",
        "avatar_url": "https://i.pravatar.cc/300?img=23",
        "banner_url": "https://images.unsplash.com/photo-1519996529931-28324d5a630e?auto=format&fit=crop&w=1200&q=80",
        "is_public": True,
        "hide_music_taste": True,
        "show_match_city": True,
        "profile_shift": 0.34,
        "genres": ["Electronic", "Alt Pop", "Indie Rock", "House", "Pop"],
        "artist_ids": [9549148, 409796, 56125],
    },
    {
        "first_name": "Kirill",
        "prefix": "demo_kirill",
        "city": "Berlin",
        "bio": "Club textures, polished beats, and zero skips after midnight.",
        "avatar_url": "https://i.pravatar.cc/300?img=14",
        "banner_url": "https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1200&q=80",
        "is_public": True,
        "hide_music_taste": False,
        "show_match_city": False,
        "profile_shift": 0.42,
        "genres": ["Electronic", "House", "Techno", "Alt Pop", "Pop"],
        "artist_ids": [5384533, 1014142, 327845761],
    },
    {
        "first_name": "Leila",
        "prefix": "demo_leila",
        "city": "Paris",
        "bio": "Slow-build songs, cinematic strings, and dramatic replay energy.",
        "avatar_url": "https://i.pravatar.cc/300?img=52",
        "banner_url": "https://images.unsplash.com/photo-1521334884684-d80222895322?auto=format&fit=crop&w=1200&q=80",
        "is_public": False,
        "hide_music_taste": True,
        "show_match_city": False,
        "profile_shift": 0.56,
        "genres": ["Dream Pop", "Chamber Pop", "Alt Pop", "Indie Rock", "R&B"],
        "artist_ids": [1058631, 78668, 74444],
    },
    {
        "first_name": "Niko",
        "prefix": "demo_niko",
        "city": "Tokyo",
        "bio": "Bright synths, faster tempos, and one heartbreak anthem for every week.",
        "avatar_url": "https://i.pravatar.cc/300?img=65",
        "banner_url": "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=1200&q=80",
        "is_public": True,
        "hide_music_taste": False,
        "show_match_city": True,
        "profile_shift": 0.68,
        "genres": ["Synthpop", "Electronic", "Pop", "Dance", "Alt Pop"],
        "artist_ids": [6807853, 13358, 7814812],
    },
]
# Not a real bcrypt hash — demo users cannot log in
_DEMO_PW_HASH = "$2b$12$demo0000000000000000000000000000000000000000000000000"


def _build_demo_vector(base: dict, shift: float) -> dict:
    vector: dict[str, float] = {}
    for index, (key, value) in enumerate(base.items()):
        weight = float(value)
        direction = 1 if index % 2 == 0 else -1
        adjusted = weight + direction * shift
        vector[key] = max(0.08, min(1.0, round(adjusted, 3)))
    return vector


@router.post(
    "/debug/seed-demo-match",
    summary="[DEV] Seed demo match users",
    description=(
        "Creates demo users with bios, avatars, banners, public/private settings, "
        "and hidden-taste variations. They already liked you so you can test matches "
        "and profile previews immediately. "
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

    base_vector = dict(my_tv.vector or _DEMO_VECTOR)
    if not base_vector:
        base_vector = dict(_DEMO_VECTOR)

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
                bio=demo["bio"],
                avatar_url=demo["avatar_url"],
                banner_url=demo["banner_url"],
                is_public=bool(demo["is_public"]),
                hide_music_taste=bool(demo["hide_music_taste"]),
                notif_settings_json={
                    "matching_enabled": True,
                    "show_match_city": bool(demo["show_match_city"]),
                },
                is_verified=True,
                is_active=True,
            )
            db.add(demo_user)
            await db.flush()

            for genre in demo.get("genres") or _DEMO_GENRES:
                db.add(UserGenre(user_id=demo_user.id, genre=genre, weight=1.0))
            for artist_id in demo.get("artist_ids") or []:
                db.add(
                    ArtistFollow(
                        user_id=demo_user.id,
                        deezer_artist_id=int(artist_id),
                    )
                )

            db.add(
                TasteVector(
                    user_id=demo_user.id,
                    vector=_build_demo_vector(base_vector, float(demo["profile_shift"])),
                )
            )
            await db.flush()
        else:
            demo_user.first_name = demo["first_name"]
            demo_user.display_name = demo["first_name"]
            demo_user.city = demo["city"]
            demo_user.bio = demo["bio"]
            demo_user.avatar_url = demo["avatar_url"]
            demo_user.banner_url = demo["banner_url"]
            demo_user.is_public = bool(demo["is_public"])
            demo_user.hide_music_taste = bool(demo["hide_music_taste"])
            existing_settings = dict(getattr(demo_user, "notif_settings_json", None) or {})
            existing_settings["matching_enabled"] = True
            existing_settings["show_match_city"] = bool(demo["show_match_city"])
            demo_user.notif_settings_json = existing_settings

            existing_genres = (
                await db.execute(select(UserGenre).where(UserGenre.user_id == demo_user.id))
            ).scalars().all()
            for row in existing_genres:
                await db.delete(row)
            existing_artist_follows = (
                await db.execute(
                    select(ArtistFollow).where(ArtistFollow.user_id == demo_user.id)
                )
            ).scalars().all()
            for row in existing_artist_follows:
                await db.delete(row)
            await db.flush()
            for genre in demo.get("genres") or _DEMO_GENRES:
                db.add(UserGenre(user_id=demo_user.id, genre=genre, weight=1.0))
            for artist_id in demo.get("artist_ids") or []:
                db.add(
                    ArtistFollow(
                        user_id=demo_user.id,
                        deezer_artist_id=int(artist_id),
                    )
                )

            existing_tv = await db.scalar(
                select(TasteVector).where(TasteVector.user_id == demo_user.id)
            )
            if existing_tv:
                existing_tv.vector = _build_demo_vector(
                    base_vector, float(demo["profile_shift"])
                )
            else:
                db.add(
                    TasteVector(
                        user_id=demo_user.id,
                        vector=_build_demo_vector(
                            base_vector, float(demo["profile_shift"])
                        ),
                    )
                )
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
                "bio": demo["bio"],
                "is_public": bool(demo["is_public"]),
                "hide_music_taste": bool(demo["hide_music_taste"]),
                "status": status,
            }
        )

    await db.commit()
    await cache_svc.invalidate_match_candidates(request.app.state.redis, [current_user.id])

    return {
        "message": "Demo match users seeded with bios, avatars, banners, privacy modes, and different taste strengths.",
        "users": results,
        "instructions": [
            "1. Open the Match tab in the app",
            "2. Lower the minimum match slider if you want to test weaker matches too",
            "3. Toggle Public only / Hide hidden taste to test different profile modes",
            "4. Tap Open profile to inspect bios, avatars, and banners",
            "5. Swipe right (like) to create a mutual match and start chat",
        ],
    }
