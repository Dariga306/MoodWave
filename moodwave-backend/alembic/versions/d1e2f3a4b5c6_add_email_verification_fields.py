"""add email verification and password reset fields to users

Revision ID: d1e2f3a4b5c6
Revises: b7c8d9e0f1a2
Create Date: 2026-03-27 00:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d1e2f3a4b5c6"
down_revision: Union[str, None] = "b7c8d9e0f1a2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _col(bind, table: str, column: str) -> bool:
    return bind.execute(
        sa.text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_schema='public' AND table_name=:t AND column_name=:c"
        ),
        {"t": table, "c": column},
    ).fetchone() is not None


def upgrade() -> None:
    bind = op.get_bind()

    # first_name / last_name
    if not _col(bind, "users", "first_name"):
        op.add_column("users", sa.Column("first_name", sa.String(100), nullable=True))
    if not _col(bind, "users", "last_name"):
        op.add_column("users", sa.Column("last_name", sa.String(100), nullable=True))

    # phone
    if not _col(bind, "users", "phone"):
        op.add_column("users", sa.Column("phone", sa.String(20), nullable=True))

    # is_verified (default False)
    if not _col(bind, "users", "is_verified"):
        op.add_column(
            "users",
            sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        )

    # email verification code + expiry
    if not _col(bind, "users", "verification_code"):
        op.add_column("users", sa.Column("verification_code", sa.String(6), nullable=True))
    if not _col(bind, "users", "verification_code_expires"):
        op.add_column("users", sa.Column("verification_code_expires", sa.DateTime(), nullable=True))

    # resend rate-limiting
    if not _col(bind, "users", "verification_resend_count"):
        op.add_column(
            "users",
            sa.Column("verification_resend_count", sa.Integer(), nullable=False, server_default="0"),
        )
    if not _col(bind, "users", "verification_resend_window"):
        op.add_column("users", sa.Column("verification_resend_window", sa.DateTime(), nullable=True))

    # password reset code + expiry
    if not _col(bind, "users", "reset_code"):
        op.add_column("users", sa.Column("reset_code", sa.String(6), nullable=True))
    if not _col(bind, "users", "reset_code_expires"):
        op.add_column("users", sa.Column("reset_code_expires", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "reset_code_expires")
    op.drop_column("users", "reset_code")
    op.drop_column("users", "verification_resend_window")
    op.drop_column("users", "verification_resend_count")
    op.drop_column("users", "verification_code_expires")
    op.drop_column("users", "verification_code")
    op.drop_column("users", "is_verified")
    op.drop_column("users", "phone")
    op.drop_column("users", "last_name")
    op.drop_column("users", "first_name")
