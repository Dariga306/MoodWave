"""add is_active to users and create user_moods table

Revision ID: a1b2c3d4e5f6
Revises: 9f4c3e1b2a10
Create Date: 2026-03-26 00:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "9f4c3e1b2a10"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()

    # Add is_active column only if it doesn't exist
    result = bind.execute(
        sa.text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name='users' AND column_name='is_active'"
        )
    )
    if not result.fetchone():
        op.add_column(
            "users",
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        )

    # Create user_moods table only if it doesn't exist
    result2 = bind.execute(
        sa.text(
            "SELECT tablename FROM pg_tables "
            "WHERE schemaname='public' AND tablename='user_moods'"
        )
    )
    if not result2.fetchone():
        op.create_table(
            "user_moods",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("mood", sa.String(length=50), nullable=False),
            sa.Column("weight", sa.Float(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_user_moods_user_id"), "user_moods", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_user_moods_user_id"), table_name="user_moods")
    op.drop_table("user_moods")
    op.drop_column("users", "is_active")
