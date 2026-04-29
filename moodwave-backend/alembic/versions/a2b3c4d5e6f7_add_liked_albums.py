"""add_liked_albums

Revision ID: a2b3c4d5e6f7
Revises: f90e0eacfbd2
Create Date: 2026-04-28 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'a2b3c4d5e6f7'
down_revision: Union[str, None] = 'f90e0eacfbd2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'liked_albums',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('album_id', sa.String(100), nullable=False),
        sa.Column('album_name', sa.String(255), nullable=False),
        sa.Column('artist_name', sa.String(255), nullable=False, server_default=''),
        sa.Column('cover_url', sa.Text(), nullable=True),
        sa.Column('liked_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_liked_albums_user', 'liked_albums', ['user_id', 'liked_at'])


def downgrade() -> None:
    op.drop_index('ix_liked_albums_user', table_name='liked_albums')
    op.drop_table('liked_albums')
