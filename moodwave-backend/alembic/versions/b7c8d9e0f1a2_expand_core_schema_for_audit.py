"""expand core schema for audit

Revision ID: b7c8d9e0f1a2
Revises: a1b2c3d4e5f6
Create Date: 2026-03-26 02:40:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7c8d9e0f1a2"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(bind, table: str, column: str) -> bool:
    row = bind.execute(
        sa.text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_schema='public' AND table_name=:table AND column_name=:column"
        ),
        {"table": table, "column": column},
    ).fetchone()
    return row is not None


def _constraint_exists(bind, name: str) -> bool:
    row = bind.execute(
        sa.text(
            "SELECT 1 FROM information_schema.table_constraints "
            "WHERE table_schema='public' AND constraint_name=:name"
        ),
        {"name": name},
    ).fetchone()
    return row is not None


def _index_exists(bind, name: str) -> bool:
    row = bind.execute(
        sa.text(
            "SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname=:name"
        ),
        {"name": name},
    ).fetchone()
    return row is not None


def upgrade() -> None:
    bind = op.get_bind()

    if not _column_exists(bind, "users", "birth_date"):
        op.add_column("users", sa.Column("birth_date", sa.Date(), nullable=True))

    if not _column_exists(bind, "playlists", "collab_user_id"):
        op.add_column("playlists", sa.Column("collab_user_id", sa.Integer(), nullable=True))
        op.create_foreign_key(
            "fk_playlists_collab_user_id_users",
            "playlists",
            "users",
            ["collab_user_id"],
            ["id"],
            ondelete="SET NULL",
        )
    if not _index_exists(bind, "ix_playlists_collab_user_id"):
        op.create_index("ix_playlists_collab_user_id", "playlists", ["collab_user_id"], unique=False)

    if not _column_exists(bind, "listening_history", "completion_pct"):
        op.add_column("listening_history", sa.Column("completion_pct", sa.Float(), nullable=True))
    if not _column_exists(bind, "listening_history", "mood"):
        op.add_column("listening_history", sa.Column("mood", sa.String(length=50), nullable=True))
    if not _column_exists(bind, "listening_history", "time_listened_ms"):
        op.add_column("listening_history", sa.Column("time_listened_ms", sa.Integer(), nullable=True))

    if not _column_exists(bind, "match_decisions", "hidden_until"):
        op.add_column("match_decisions", sa.Column("hidden_until", sa.DateTime(), nullable=True))

    if not _column_exists(bind, "chats", "match_id"):
        op.add_column("chats", sa.Column("match_id", sa.Integer(), nullable=True))
        op.create_foreign_key(
            "fk_chats_match_id_matches",
            "chats",
            "matches",
            ["match_id"],
            ["id"],
            ondelete="CASCADE",
        )
    if not _index_exists(bind, "ix_chats_match_id"):
        op.create_index("ix_chats_match_id", "chats", ["match_id"], unique=True)

    if not _column_exists(bind, "listening_rooms", "closed_at"):
        op.add_column("listening_rooms", sa.Column("closed_at", sa.DateTime(), nullable=True))

    if not _column_exists(bind, "room_participants", "left_at"):
        op.add_column("room_participants", sa.Column("left_at", sa.DateTime(), nullable=True))
    if not _column_exists(bind, "room_participants", "created_at"):
        op.add_column(
            "room_participants",
            sa.Column("created_at", sa.DateTime(), nullable=True, server_default=sa.text("now()")),
        )
        op.execute("UPDATE room_participants SET created_at = now() WHERE created_at IS NULL")
        op.alter_column("room_participants", "created_at", nullable=False, server_default=None)

    # Remove duplicates before adding unique constraints.
    op.execute(
        """
        DELETE FROM user_genres ug
        USING user_genres ug2
        WHERE ug.id > ug2.id
          AND ug.user_id = ug2.user_id
          AND lower(ug.genre) = lower(ug2.genre)
        """
    )
    op.execute(
        """
        DELETE FROM user_moods um
        USING user_moods um2
        WHERE um.id > um2.id
          AND um.user_id = um2.user_id
          AND lower(um.mood) = lower(um2.mood)
        """
    )

    if not _constraint_exists(bind, "uq_user_genres_user_genre"):
        op.create_unique_constraint(
            "uq_user_genres_user_genre",
            "user_genres",
            ["user_id", "genre"],
        )
    if not _constraint_exists(bind, "uq_user_moods_user_mood"):
        op.create_unique_constraint(
            "uq_user_moods_user_mood",
            "user_moods",
            ["user_id", "mood"],
        )


def downgrade() -> None:
    op.drop_constraint("uq_user_moods_user_mood", "user_moods", type_="unique")
    op.drop_constraint("uq_user_genres_user_genre", "user_genres", type_="unique")

    op.drop_column("room_participants", "created_at")
    op.drop_column("room_participants", "left_at")
    op.drop_column("listening_rooms", "closed_at")

    op.drop_index("ix_chats_match_id", table_name="chats")
    op.drop_constraint("fk_chats_match_id_matches", "chats", type_="foreignkey")
    op.drop_column("chats", "match_id")

    op.drop_column("match_decisions", "hidden_until")

    op.drop_column("listening_history", "time_listened_ms")
    op.drop_column("listening_history", "mood")
    op.drop_column("listening_history", "completion_pct")

    op.drop_index("ix_playlists_collab_user_id", table_name="playlists")
    op.drop_constraint("fk_playlists_collab_user_id_users", "playlists", type_="foreignkey")
    op.drop_column("playlists", "collab_user_id")

    op.drop_column("users", "birth_date")
