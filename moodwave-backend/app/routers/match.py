from __future__ import annotations

import asyncio
import json
import random
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import and_, or_, select, true
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.chat import Chat
from app.models.social import ArtistFollow, Match, MatchDecision
from app.models.user import TasteVector, User, UserGenre
from app.schemas.match import DecisionRequest
from app.services import cache as cache_svc
from app.services import deezer as deezer_service
from app.services import firebase as firebase_svc
from app.services.matching import MATCH_THRESHOLD, calculate_match_percent, generate_icebreaker
from app.services.security import users_are_blocked

router = APIRouter()

MATCH_CANDIDATE_CACHE_TTL = 3600

ICEBREAKERS = [
    "You both have great overlap in late-night tracks. Start with one song each?",
    "Your taste vectors are close. Ask what they replay most this week.",
    "High compatibility. Share one comfort track and compare moods.",
    "Looks like a strong match. Try trading top three artists.",
]


def _icebreaker() -> str:
    return random.choice(ICEBREAKERS)


def _match_settings(user: User) -> dict:
    return dict(getattr(user, "notif_settings_json", None) or {})


def _matching_enabled(user: User) -> bool:
    return bool(_match_settings(user).get("matching_enabled", True))


def _show_match_city(user: User) -> bool:
    return bool(_match_settings(user).get("show_match_city", True))


async def _presence_payload(redis, user: User) -> dict:
    payload = None
    try:
        raw = await redis.get(f"presence:{user.id}")
        payload = json.loads(raw) if raw else None
    except Exception:
        payload = None
    if isinstance(payload, dict):
        last_seen_at = payload.get("last_seen_at")
    else:
        try:
            last_seen_at = await redis.get(f"last_seen:{user.id}")
        except Exception:
            last_seen_at = None
    return {
        "is_online": bool(payload),
        "presence_status": "online" if payload else "offline",
        "last_seen_at": last_seen_at,
    }


async def _decided_target_ids(db: AsyncSession, user_id: int) -> set[int]:
    rows = (
        await db.execute(
            select(MatchDecision.target_user_id).where(
                MatchDecision.user_id == user_id,
                or_(
                    MatchDecision.hidden_until.is_(None),
                    MatchDecision.hidden_until > datetime.utcnow(),
                ),
            )
        )
    ).all()
    return {row[0] for row in rows}


def _dedupe_artist_name(value: str) -> str:
    normalized = " ".join(value.lower().strip().split())
    for splitter in (" feat. ", " ft. ", " featuring ", " & ", ", ", " x "):
        if splitter in normalized:
            normalized = normalized.split(splitter, 1)[0].strip()
    return normalized


async def _favorite_artist_preview(
    db: AsyncSession,
    user_id: int,
    *,
    limit: int = 3,
) -> list[dict]:
    artist_ids = (
        await db.execute(
            select(ArtistFollow.deezer_artist_id)
            .where(ArtistFollow.user_id == user_id)
            .order_by(ArtistFollow.created_at.desc())
            .limit(limit * 3)
        )
    ).scalars().all()
    if not artist_ids:
        return []

    artists = await asyncio.gather(
        *[deezer_service.get_artist(int(artist_id)) for artist_id in artist_ids[: limit * 3]],
        return_exceptions=True,
    )
    payload: list[dict] = []
    seen: set[str] = set()
    for artist in artists:
        if not isinstance(artist, dict):
            continue
        name = (artist.get("name") or "").strip()
        if not name:
            continue
        key = _dedupe_artist_name(name)
        if not key or key in seen:
            continue
        seen.add(key)
        payload.append(
            {
                "id": artist.get("id"),
                "name": name,
                "image_url": artist.get("picture_medium")
                or artist.get("picture_big")
                or artist.get("picture_xl")
                or artist.get("picture"),
            }
        )
        if len(payload) >= limit:
            break
    return payload


@router.get(
    "",
    summary="Get match candidates",
    description="Returns verified match candidates for the current user with similarity scores, top genres, and icebreakers.",
)
@router.get(
    "/",
    summary="Get match candidates",
    description="Returns verified match candidates for the current user with similarity scores, top genres, and icebreakers.",
)
@router.get(
    "/candidates",
    summary="Get match candidates",
    description="Returns verified match candidates for the current user with similarity scores, top genres, and icebreakers.",
)
async def get_candidates(
    city: str | None = Query(default=None),
    only_online: bool = Query(default=False),
    only_public: bool = Query(default=False),
    exclude_hidden_taste: bool = Query(default=True),
    min_similarity: int = Query(default=0, ge=0, le=100),
    limit: int = Query(default=10, ge=1, le=50),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    if not _matching_enabled(current_user):
        return {"candidates": [], "matching_enabled": False}
    cache_key = (
        "match_candidates:"
        f"{current_user.id}:{(city or '').lower()}:{only_online}:{only_public}:"
        f"{exclude_hidden_taste}:{min_similarity}:{limit}"
    )
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    my_tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    if not my_tv or not my_tv.vector:
        response = {"candidates": []}
        await redis.setex(cache_key, MATCH_CANDIDATE_CACHE_TTL, json.dumps(response))
        return response

    excluded_ids = await _decided_target_ids(db, current_user.id)
    excluded_ids.add(current_user.id)

    all_tvs_q = select(TasteVector, User).join(User, User.id == TasteVector.user_id).where(
        TasteVector.user_id.notin_(excluded_ids) if excluded_ids else true(),
    )
    if city:
        all_tvs_q = all_tvs_q.where(User.city.ilike(f"%{city.strip()}%"))

    rows = (await db.execute(all_tvs_q)).all()
    candidates: list[dict] = []
    for tv, user in rows:
        if not tv.vector:
            continue
        if await users_are_blocked(db, current_user.id, user.id):
            continue
        if not _matching_enabled(user):
            continue
        if city and not _show_match_city(user):
            continue
        if only_public and not user.is_public:
            continue

        similarity = calculate_match_percent(my_tv.vector, tv.vector)
        if similarity < min_similarity:
            continue
        if getattr(user, "hide_music_taste", False) and exclude_hidden_taste:
            continue

        presence = await _presence_payload(redis, user)
        if only_online and not presence["is_online"]:
            continue

        # Fetch genres for both users for icebreaker generation
        my_genres_rows = (
            await db.execute(select(UserGenre.genre).where(UserGenre.user_id == current_user.id))
        ).scalars().all()
        their_genres_rows = (
            await db.execute(select(UserGenre.genre).where(UserGenre.user_id == user.id))
        ).scalars().all()
        my_genres = list(my_genres_rows)
        their_genres = list(their_genres_rows)

        # Top genres for display (sorted by vector weight)
        top_genres = []
        artist_preview: list[dict] = []
        if not getattr(user, "hide_music_taste", False):
            top_genres = sorted(
                [
                    (k.replace("genre:", "").replace("_", " "), float(v))
                    for k, v in tv.vector.items()
                    if k.startswith("genre:") and float(v) > 0.3
                ],
                key=lambda x: x[1],
                reverse=True,
            )[:5]
            artist_preview = await _favorite_artist_preview(
                db,
                user.id,
                limit=3,
            )
        city_value = user.city if _show_match_city(user) else ""
        visible_genres = [g for g, _ in top_genres]
        taste_summary = (
            " · ".join(visible_genres[:3])
            if visible_genres
            else "Music taste hidden"
            if getattr(user, "hide_music_taste", False)
            else "Discover their taste after matching"
        )

        candidates.append(
            {
                "user_id": user.id,
                "username": user.username,
                "display_name": user.display_name,
                "first_name": user.first_name,
                "avatar_url": user.avatar_url,
                "banner_url": getattr(user, "banner_url", None),
                "updated_at": user.updated_at.isoformat() if user.updated_at else None,
                "bio": user.bio,
                "city": city_value,
                "is_public": user.is_public,
                "profile_mode": "public" if user.is_public else "private",
                "is_verified": user.is_verified,
                "similarity_pct": similarity,
                "top_genres": visible_genres,
                "artist_preview": artist_preview,
                "artist_preview_names": [item.get("name", "") for item in artist_preview],
                "taste_summary": taste_summary,
                "music_taste_visible": not getattr(user, "hide_music_taste", False),
                "matching_enabled": True,
                "show_match_city": _show_match_city(user),
                **presence,
                "icebreaker": generate_icebreaker(my_tv.vector, tv.vector, my_genres, their_genres),
            }
        )

    candidates.sort(key=lambda item: item["similarity_pct"], reverse=True)
    response = {"candidates": candidates[:limit], "matching_enabled": True}
    await redis.setex(cache_key, MATCH_CANDIDATE_CACHE_TTL, json.dumps(response))
    return response


@router.post(
    "/{target_user_id}/like",
    summary="Like match candidate",
    description="Records a like for a candidate, creates a mutual match and chat when the other user already liked back.",
)
@router.post(
    "/decide/{target_user_id}",
    summary="Like match candidate",
    description="Compatibility alias for recording a like decision that can also create a mutual match and chat.",
)
async def like_user(
    target_user_id: int,
    body: DecisionRequest | None = None,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body and body.decision == "skip":
        return await skip_user(target_user_id, request=request, db=db, current_user=current_user)

    if target_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot like yourself")
    if await users_are_blocked(db, current_user.id, target_user_id):
        raise HTTPException(status_code=403, detail="User is blocked")

    existing_decision = await db.scalar(
        select(MatchDecision).where(
            MatchDecision.user_id == current_user.id,
            MatchDecision.target_user_id == target_user_id,
            or_(
                MatchDecision.hidden_until.is_(None),
                MatchDecision.hidden_until > datetime.utcnow(),
            ),
        )
    )
    if existing_decision:
        raise HTTPException(status_code=400, detail="Already decided")

    db.add(MatchDecision(user_id=current_user.id, target_user_id=target_user_id, decision="like"))
    await db.flush()

    reciprocal = await db.scalar(
        select(MatchDecision).where(
            MatchDecision.user_id == target_user_id,
            MatchDecision.target_user_id == current_user.id,
            MatchDecision.decision == "like",
        )
    )
    if not reciprocal:
        await db.commit()
        await cache_svc.invalidate_match_candidates(
            request.app.state.redis,
            [current_user.id, target_user_id],
        )
        target_user = await db.get(User, target_user_id)
        await firebase_svc.send_push_notification_to_user(
            user=target_user,
            setting_key="like_back",
            title="Someone liked you",
            body=f"{current_user.display_name or current_user.first_name or current_user.username} liked your music taste. Like back to start chatting together.",
            data={"event": "music_like", "user_id": current_user.id},
        )
        return {"is_mutual": False}

    # Mutual like -> create match + chat
    my_tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    their_tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == target_user_id))
    similarity_pct = 0
    if my_tv and their_tv and my_tv.vector and their_tv.vector:
        similarity_pct = calculate_match_percent(my_tv.vector, their_tv.vector)

    existing_match = await db.scalar(
        select(Match).where(
            or_(
                and_(Match.user_a_id == current_user.id, Match.user_b_id == target_user_id),
                and_(Match.user_a_id == target_user_id, Match.user_b_id == current_user.id),
            )
        )
    )
    if existing_match:
        match = existing_match
    else:
        user_a, user_b = sorted([current_user.id, target_user_id])
        match = Match(user_a_id=user_a, user_b_id=user_b, similarity_pct=similarity_pct)
        db.add(match)
        await db.flush()

    chat = await db.scalar(select(Chat).where(Chat.match_id == match.id))
    if not chat:
        firebase_chat_id = f"chat_{min(current_user.id, target_user_id)}_{max(current_user.id, target_user_id)}"
        chat = Chat(
            match_id=match.id,
            user_a_id=min(current_user.id, target_user_id),
            user_b_id=max(current_user.id, target_user_id),
            firebase_chat_id=firebase_chat_id,
        )
        db.add(chat)
        await db.flush()
        await firebase_svc.create_chat_node(firebase_chat_id, chat.user_a_id, chat.user_b_id)

    await db.commit()
    await cache_svc.invalidate_match_candidates(
        request.app.state.redis,
        [current_user.id, target_user_id],
    )

    target_user = await db.get(User, target_user_id)
    await firebase_svc.send_push_notification_to_user(
        user=current_user,
        setting_key="match_found",
        title="Match found",
        body=f"You matched with {target_user.username if target_user else 'someone'}",
        data={"event": "match_found", "match_id": match.id},
    )
    await firebase_svc.send_push_notification_to_user(
        user=target_user,
        setting_key="match_found",
        title="Match found",
        body=f"You matched with {current_user.username}",
        data={"event": "match_found", "match_id": match.id},
    )
    return {
        "is_mutual": True,
        "match_id": match.id,
        "chat_id": chat.id,
        "firebase_chat_id": chat.firebase_chat_id,
    }


@router.post(
    "/{target_user_id}/skip",
    summary="Skip match candidate",
    description="Records a skip decision and hides the candidate from matching results for seven days.",
)
async def skip_user(
    target_user_id: int,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if target_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot skip yourself")

    existing_decision = await db.scalar(
        select(MatchDecision).where(
            MatchDecision.user_id == current_user.id,
            MatchDecision.target_user_id == target_user_id,
            or_(
                MatchDecision.hidden_until.is_(None),
                MatchDecision.hidden_until > datetime.utcnow(),
            ),
        )
    )
    if existing_decision:
        raise HTTPException(status_code=400, detail="Already decided")

    db.add(
        MatchDecision(
            user_id=current_user.id,
            target_user_id=target_user_id,
            decision="skip",
            hidden_until=datetime.utcnow() + timedelta(days=7),
        )
    )
    await db.commit()
    await cache_svc.invalidate_match_candidates(
        request.app.state.redis,
        [current_user.id, target_user_id],
    )
    return {"is_mutual": False}


@router.get(
    "/confirmed",
    summary="Get confirmed matches",
    description="Returns mutual matches for the current user, excluding users involved in blocking relationships.",
)
async def confirmed_matches(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(Match, User)
            .where(or_(Match.user_a_id == current_user.id, Match.user_b_id == current_user.id))
            .join(
                User,
                or_(
                    and_(Match.user_a_id == current_user.id, User.id == Match.user_b_id),
                    and_(Match.user_b_id == current_user.id, User.id == Match.user_a_id),
                ),
            )
            .order_by(Match.created_at.desc())
        )
    ).all()
    return {
        "matches": [
            {
                "match_id": match.id,
                "similarity_pct": match.similarity_pct,
                "matched_at": match.created_at.isoformat(),
                "user": {
                    "id": other.id,
                    "username": other.username,
                    "display_name": other.display_name,
                    "avatar_url": other.avatar_url,
                },
            }
            for match, other in rows
            if not await users_are_blocked(db, current_user.id, other.id)
        ]
    }


@router.get(
    "/taste-vector",
    summary="Get match taste vector",
    description="Returns the raw taste vector data used by the match system for the current user.",
)
async def taste_vector(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == current_user.id))
    return {"vector": tv.vector if tv and tv.vector else {}}
