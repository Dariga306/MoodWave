"""add listening room background url

Revision ID: f1a2b3c4d5e6
Revises: e7f8a9b0c1d2
Create Date: 2026-05-11
"""

from alembic import op
import sqlalchemy as sa


revision = "f1a2b3c4d5e6"
down_revision = "e7f8a9b0c1d2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("listening_rooms", sa.Column("background_url", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("listening_rooms", "background_url")
