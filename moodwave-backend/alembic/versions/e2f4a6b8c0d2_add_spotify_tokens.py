"""add_spotify_tokens

Revision ID: e2f4a6b8c0d2
Revises: 4cf54c834428
Create Date: 2026-04-03 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e2f4a6b8c0d2'
down_revision: Union[str, None] = '4cf54c834428'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('spotify_access_token', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('spotify_refresh_token', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('spotify_token_expires_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'spotify_token_expires_at')
    op.drop_column('users', 'spotify_refresh_token')
    op.drop_column('users', 'spotify_access_token')
