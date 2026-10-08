"""Make phone numbers unique.

Revision ID: c4a7d1e9f203
Revises: 9eb54957ba46
Create Date: 2026-09-29
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c4a7d1e9f203"
down_revision: Union[str, Sequence[str], None] = "9eb54957ba46"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()

    duplicate_phone = connection.execute(
        sa.text(
            """
            SELECT phone_number
            FROM users
            GROUP BY phone_number
            HAVING COUNT(*) > 1
            LIMIT 1
            """
        )
    ).first()

    if duplicate_phone is not None:
        raise RuntimeError(
            "Cannot make users.phone_number unique while duplicate "
            "phone numbers exist. Resolve the duplicates and run the "
            "migration again."
        )

    op.create_index(
        "ix_users_phone_number",
        "users",
        ["phone_number"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_users_phone_number",
        table_name="users",
    )
