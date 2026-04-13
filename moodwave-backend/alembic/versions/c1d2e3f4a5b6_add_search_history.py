"""add_search_history

Revision ID: c1d2e3f4a5b6
Revises: f3a4b5c6d7e8
Create Date: 2026-04-09 00:20:00.000000

"""
from typing import Sequence, Union

from alembic import op


revision: str = "c1d2e3f4a5b6"
down_revision: Union[str, None] = "f3a4b5c6d7e8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS search_history (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
            query VARCHAR(200) NOT NULL,
            result_type VARCHAR(20) NOT NULL,
            result_id VARCHAR(100),
            result_title VARCHAR(200),
            result_cover VARCHAR(500),
            created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
        )
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_search_history_user_id
        ON search_history (user_id)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_search_history_user_id")
    op.execute("DROP TABLE IF EXISTS search_history")
