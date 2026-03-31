"""add search indexes

Revision ID: 9f4c3e1b2a10
Revises: 88fb9eeebb28
Create Date: 2026-03-25 21:20:00.000000
"""

from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "9f4c3e1b2a10"
down_revision: Union[str, None] = "88fb9eeebb28"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_playlists_search
        ON playlists
        USING GIN (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, '')))
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_users_search
        ON users
        USING GIN (to_tsvector('simple', coalesce(username, '') || ' ' || coalesce(display_name, '')))
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_playlists_search")
    op.execute("DROP INDEX IF EXISTS idx_users_search")
