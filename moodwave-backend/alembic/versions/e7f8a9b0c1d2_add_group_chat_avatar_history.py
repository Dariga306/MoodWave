"""add_group_chat_avatar_history

Revision ID: e7f8a9b0c1d2
Revises: z9a8b7c6d5e4
Create Date: 2026-05-10 22:45:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "e7f8a9b0c1d2"
down_revision = "z9a8b7c6d5e4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    table_name = "group_chat_avatar_history"
    existing_indexes = {
        index["name"] for index in inspector.get_indexes(table_name)
    } if inspector.has_table(table_name) else set()

    if not inspector.has_table(table_name):
        op.create_table(
            table_name,
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("group_chat_id", sa.Integer(), nullable=False),
            sa.Column("avatar_url", sa.Text(), nullable=False),
            sa.Column("changed_by_user_id", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(
                ["changed_by_user_id"],
                ["users.id"],
                ondelete="SET NULL",
            ),
            sa.ForeignKeyConstraint(
                ["group_chat_id"],
                ["group_chats.id"],
                ondelete="CASCADE",
            ),
            sa.PrimaryKeyConstraint("id"),
        )
        inspector = sa.inspect(bind)
        existing_indexes = {
            index["name"] for index in inspector.get_indexes(table_name)
        }

    changed_by_index = op.f("ix_group_chat_avatar_history_changed_by_user_id")
    if changed_by_index not in existing_indexes:
        op.create_index(
            changed_by_index,
            table_name,
            ["changed_by_user_id"],
            unique=False,
        )
    group_index = op.f("ix_group_chat_avatar_history_group_chat_id")
    if group_index not in existing_indexes:
        op.create_index(
            group_index,
            table_name,
            ["group_chat_id"],
            unique=False,
        )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_group_chat_avatar_history_group_chat_id"),
        table_name="group_chat_avatar_history",
    )
    op.drop_index(
        op.f("ix_group_chat_avatar_history_changed_by_user_id"),
        table_name="group_chat_avatar_history",
    )
    op.drop_table("group_chat_avatar_history")
