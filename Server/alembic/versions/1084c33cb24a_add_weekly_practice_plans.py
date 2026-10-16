"""Add weekly practice plans

Revision ID: 1084c33cb24a
Revises: 8ffeed59a913
Create Date: 2026-10-15 02:13:21.596959

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1084c33cb24a'
down_revision: Union[str, Sequence[str], None] = '8ffeed59a913'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "weekly_plans",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "week_start",
            name="uq_weekly_plans_user_week",
        ),
    )

    op.create_table(
        "planned_practice_sessions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("plan_id", sa.Integer(), nullable=False),
        sa.Column("practice_date", sa.Date(), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=False),
        sa.Column(
            "is_completed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "completed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(
            ["plan_id"],
            ["weekly_plans.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "plan_id",
            "practice_date",
            name="uq_planned_practice_sessions_plan_date",
        ),
        sa.CheckConstraint(
            "duration_minutes > 0",
            name="ck_planned_practice_sessions_positive_duration",
        ),
    )


def downgrade() -> None:
    op.drop_table("planned_practice_sessions")
    op.drop_table("weekly_plans")
