"""Add repeating weekly practice schedules

Revision ID: f0d5dd903635
Revises: b926f16d7260
Create Date: 2026-10-22 02:49:39.224522

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f0d5dd903635'
down_revision: Union[str, Sequence[str], None] = 'b926f16d7260'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "weekly_practice_schedules",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("sessions", sa.JSON(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id"),
    )


def downgrade() -> None:
    op.drop_table("weekly_practice_schedules")
