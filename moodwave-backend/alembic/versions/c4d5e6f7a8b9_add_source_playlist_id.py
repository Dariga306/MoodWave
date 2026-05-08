"""add_source_playlist_id

Revision ID: c4d5e6f7a8b9
Revises: b3c4d5e6f7a8
Create Date: 2026-05-08 19:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c4d5e6f7a8b9'
down_revision: Union[str, None] = 'b3c4d5e6f7a8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'playlists',
        sa.Column('source_playlist_id', sa.Integer(), nullable=True),
    )
    op.create_index(
        'ix_playlists_source_playlist_id',
        'playlists',
        ['source_playlist_id'],
        unique=False,
    )
    op.create_foreign_key(
        'fk_playlists_source_playlist_id_playlists',
        'playlists',
        'playlists',
        ['source_playlist_id'],
        ['id'],
        ondelete='SET NULL',
    )


def downgrade() -> None:
    op.drop_constraint(
        'fk_playlists_source_playlist_id_playlists',
        'playlists',
        type_='foreignkey',
    )
    op.drop_index('ix_playlists_source_playlist_id', table_name='playlists')
    op.drop_column('playlists', 'source_playlist_id')
