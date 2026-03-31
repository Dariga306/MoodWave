from __future__ import annotations

from typing import Iterable


async def _delete_by_patterns(redis, patterns: Iterable[str]) -> None:
    keys: list[str] = []
    for pattern in patterns:
        async for key in redis.scan_iter(match=pattern):
            keys.append(key)
    if keys:
        await redis.delete(*keys)


async def invalidate_match_candidates(redis, user_ids: Iterable[int]) -> None:
    try:
        await _delete_by_patterns(
            redis,
            [f"match_candidates:{int(user_id)}:*" for user_id in user_ids],
        )
    except Exception:
        # Cache invalidation should never break request flow.
        return


async def invalidate_recommendations(redis, user_id: int) -> None:
    try:
        await _delete_by_patterns(redis, [f"recommendations:{int(user_id)}:*"])
    except Exception:
        return


async def invalidate_search_results_for_users(redis, user_ids: Iterable[int]) -> None:
    try:
        await _delete_by_patterns(
            redis,
            [f"search:*:limit:*:user:{int(user_id)}" for user_id in user_ids],
        )
    except Exception:
        return


async def invalidate_all_search_results(redis) -> None:
    try:
        await _delete_by_patterns(redis, ["search:*:limit:*"])
    except Exception:
        return
