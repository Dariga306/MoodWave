"""add_artist_follows

Revision ID: f3a4b5c6d7e8
Revises: e2f4a6b8c0d2
Create Date: 2026-04-07 16:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f3a4b5c6d7e8"
down_revision: Union[str, None] = "e2f4a6b8c0d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "artist_follows",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("deezer_artist_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "deezer_artist_id"),
    )
    op.create_index(op.f("ix_artist_follows_user_id"), "artist_follows", ["user_id"], unique=False)
    op.create_index(
        op.f("ix_artist_follows_deezer_artist_id"),
        "artist_follows",
        ["deezer_artist_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_artist_follows_deezer_artist_id"), table_name="artist_follows")
    op.drop_index(op.f("ix_artist_follows_user_id"), table_name="artist_follows")
    op.drop_table("artist_follows")
