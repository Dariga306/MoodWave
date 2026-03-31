"""add verification and reset fields

Revision ID: 95907afa0cfa
Revises: d1e2f3a4b5c6
Create Date: 2026-03-26 20:40:44.602702

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '95907afa0cfa'
down_revision: Union[str, None] = 'd1e2f3a4b5c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add reset_token and reset_token_expires columns
    op.add_column('users', sa.Column('reset_token', sa.String(length=512), nullable=True))
    op.add_column('users', sa.Column('reset_token_expires', sa.DateTime(), nullable=True))
    # Add unique constraint on phone (nullable — multiple NULLs still allowed in PG)
    bind = op.get_bind()
    exists = bind.execute(
        sa.text(
            "SELECT 1 FROM information_schema.table_constraints "
            "WHERE table_schema='public' AND table_name='users' "
            "AND constraint_type='UNIQUE' "
            "AND constraint_name LIKE '%phone%'"
        )
    ).fetchone()
    if not exists:
        op.create_unique_constraint('uq_users_phone', 'users', ['phone'])


def downgrade() -> None:
    op.drop_constraint('uq_users_phone', 'users', type_='unique')
    op.drop_column('users', 'reset_token_expires')
    op.drop_column('users', 'reset_token')
