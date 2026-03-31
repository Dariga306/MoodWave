import json
import math
from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import TasteVector

ACTION_WEIGHTS = {
    "liked": 3,
    "disliked": -3,
    "completed": 2,
    "added_to_playlist": 3,
    "replayed": 4,
    "skipped_early": -2,
    "skipped": -1,
    "played": 1,
}

MATCH_THRESHOLD = 75

def calculate_match_percent(vec_a: dict, vec_b: dict) -> int:
    """Calculate cosine similarity between two taste vectors, returns 0-100."""
    all_keys = list(set(vec_a) | set(vec_b))
    if not all_keys:
        return 0

    dot = sum(vec_a.get(k, 0.0) * vec_b.get(k, 0.0) for k in all_keys)
    mag_a = math.sqrt(sum(v ** 2 for v in vec_a.values()))
    mag_b = math.sqrt(sum(v ** 2 for v in vec_b.values()))

    if mag_a == 0 or mag_b == 0:
        return 0

    similarity = dot / (mag_a * mag_b)
    # Clamp to [0, 1] in case of floating point errors
    similarity = max(0.0, min(1.0, similarity))
    return round(similarity * 100)


def generate_icebreaker(vec_a: dict, vec_b: dict, genres_a: list[str], genres_b: list[str]) -> str:
    """Generate a personalized icebreaker based on shared taste vector features."""
    genres_in_a = {
        k.replace("genre:", "").replace("_", " "): float(v)
        for k, v in vec_a.items()
        if k.startswith("genre:") and float(v) > 0.4
    }
    genres_in_b = {
        k.replace("genre:", "").replace("_", " "): float(v)
        for k, v in vec_b.items()
        if k.startswith("genre:") and float(v) > 0.4
    }
    common = sorted(
        [(g, min(genres_in_a[g], genres_in_b[g])) for g in genres_in_a if g in genres_in_b],
        key=lambda x: x[1],
        reverse=True,
    )
    time_labels = {
        "time_night": "late at night 🌙",
        "time_evening": "in the evenings",
        "time_morning": "in the mornings",
        "time_day": "during the day",
    }
    common_times = [k for k in time_labels if float(vec_a.get(k, 0)) > 0.5 and float(vec_b.get(k, 0)) > 0.5]
    if len(common) >= 2:
        return f"Both of you have {common[0][0]} and {common[1][0]} in your top genres \u2728"
    elif len(common) == 1:
        genre = common[0][0]
        if common_times and "night" in common_times[0]:
            return f"You've both been listening to {genre} late at night \U0001f319"
        if common_times:
            return f"You both love {genre} \u2014 and your listening hours perfectly overlap \U0001f3a7"
        return f"Your {genre} taste is almost identical \u2014 rare to find that"
    return "You both have unique taste \u2014 discover something new together \U0001f3b5"


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, round(value, 4)))


def _time_bucket_key(now: datetime) -> str:
    hour = now.hour
    if 5 <= hour < 12:
        return "time_morning"
    if 12 <= hour < 17:
        return "time_day"
    if 17 <= hour < 22:
        return "time_evening"
    return "time_night"


def _apply_weight(current: float, delta: float) -> float:
    # Keep updates smooth and bounded.
    return _clamp01(current + (delta / 10.0))


def update_taste_vector(
    vector: dict,
    spotify_track_id: str,
    action: str,
    genres: list[str],
    mood: Optional[str] = None,
    now: Optional[datetime] = None,
) -> dict:
    """Update taste vector using action, genres, mood and time-of-day buckets.

    All values are clamped to [0.0, 1.0].
    """
    weight = ACTION_WEIGHTS.get(action, 0)
    new_vector = dict(vector)
    current_now = now or datetime.utcnow()

    # Track affinity
    track_key = f"track:{spotify_track_id}"
    new_vector[track_key] = _apply_weight(float(new_vector.get(track_key, 0.5)), weight)

    # Genres from cache/API
    for genre in genres:
        genre_key = f"genre:{genre.lower().replace(' ', '_')}"
        new_vector[genre_key] = _apply_weight(float(new_vector.get(genre_key, 0.5)), weight)

    # Mood bucket from request context (study/workout/etc.)
    if mood:
        mood_key = f"mood_{mood.lower()}"
        new_vector[mood_key] = _apply_weight(float(new_vector.get(mood_key, 0.5)), weight)

    # Time-of-day preference
    bucket_key = _time_bucket_key(current_now)
    new_vector[bucket_key] = _apply_weight(float(new_vector.get(bucket_key, 0.5)), weight)

    return new_vector


async def update_taste_vector_for_user(
    db: AsyncSession,
    redis,
    user_id: int,
    spotify_track_id: str,
    action: str,
    genres: list[str],
    mood: Optional[str] = None,
) -> dict:
    tv = await db.scalar(select(TasteVector).where(TasteVector.user_id == user_id))
    if not tv:
        tv = TasteVector(user_id=user_id, vector={})
        db.add(tv)
        await db.flush()

    tv.vector = update_taste_vector(
        vector=tv.vector or {},
        spotify_track_id=spotify_track_id,
        action=action,
        genres=genres,
        mood=mood,
    )
    await db.commit()

    try:
        await redis.setex(f"taste_vector:{user_id}", 3600, json.dumps(tv.vector))
    except Exception:
        pass
    return tv.vector


async def recalculate_all_vectors(db: AsyncSession, redis) -> None:
    rows = (await db.execute(select(TasteVector))).scalars().all()
    for row in rows:
        normalized = {
            key: _clamp01(float(value))
            for key, value in (row.vector or {}).items()
            if isinstance(value, (int, float))
        }
        row.vector = normalized
        try:
            await redis.setex(f"taste_vector:{row.user_id}", 3600, json.dumps(normalized))
        except Exception:
            pass
    await db.commit()
