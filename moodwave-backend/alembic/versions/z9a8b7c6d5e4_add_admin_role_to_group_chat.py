"""add_admin_role_to_group_chat

Revision ID: z9a8b7c6d5e4
Revises: c4d5e6f7a8b9
Create Date: 2026-05-10 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "z9a8b7c6d5e4"
down_revision: Union[str, None] = "c4d5e6f7a8b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE groupchatrole ADD VALUE IF NOT EXISTS 'admin'")


def downgrade() -> None:
    pass
