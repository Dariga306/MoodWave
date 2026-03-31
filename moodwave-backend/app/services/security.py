from __future__ import annotations

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import Block, Friend, FriendStatus


async def get_blocked_ids_for_user(db: AsyncSession, user_id: int) -> set[int]:
    blocked_q = await db.execute(
        select(Block.blocked_id).where(Block.blocker_id == user_id)
    )
    blocked_by_q = await db.execute(
        select(Block.blocker_id).where(Block.blocked_id == user_id)
    )
    return {row[0] for row in blocked_q.fetchall()} | {row[0] for row in blocked_by_q.fetchall()}


async def users_are_blocked(db: AsyncSession, user_a_id: int, user_b_id: int) -> bool:
    block = await db.scalar(
        select(Block).where(
            or_(
                and_(Block.blocker_id == user_a_id, Block.blocked_id == user_b_id),
                and_(Block.blocker_id == user_b_id, Block.blocked_id == user_a_id),
            )
        )
    )
    return block is not None


async def are_friends(db: AsyncSession, user_a_id: int, user_b_id: int) -> bool:
    friendship = await db.scalar(
        select(Friend).where(
            or_(
                and_(Friend.requester_id == user_a_id, Friend.addressee_id == user_b_id),
                and_(Friend.requester_id == user_b_id, Friend.addressee_id == user_a_id),
            ),
            Friend.status == FriendStatus.accepted,
        )
    )
    return friendship is not None
