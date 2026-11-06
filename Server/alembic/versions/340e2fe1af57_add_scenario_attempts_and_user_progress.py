
"""add scenario attempts and user progress

Revision ID: 340e2fe1af57
Revises: ba87e4728f8c
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "340e2fe1af57"
down_revision: Union[str, Sequence[str], None] = "ba87e4728f8c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "scenario_attempts",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("scenario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "scenario_difficulty_id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("ended_at", sa.DateTime(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("end_reason", sa.String(length=40), nullable=True),
        sa.Column(
            "analysis_result",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"]
        ),
        sa.ForeignKeyConstraint(
            ["scenario_id"], ["scenarios.id"]
        ),
        sa.ForeignKeyConstraint(
            ["scenario_difficulty_id"],
            ["scenario_difficulties.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_scenario_attempts_user_id",
        "scenario_attempts",
        ["user_id"],
        unique=False,
    )

    op.create_index(
        "ix_scenario_attempts_scenario_id",
        "scenario_attempts",
        ["scenario_id"],
        unique=False,
    )

    op.create_table(
        "scenario_user_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("scenario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "latest_attempt_id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column(
            "best_attempt_id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["scenario_id"], ["scenarios.id"]),
        sa.ForeignKeyConstraint(
            ["latest_attempt_id"],
            ["scenario_attempts.id"],
        ),
        sa.ForeignKeyConstraint(
            ["best_attempt_id"],
            ["scenario_attempts.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "scenario_id",
            name="uq_scenario_user_progress",
        ),
    )


def downgrade() -> None:
    op.drop_table("scenario_user_progress")

    op.drop_index(
        "ix_scenario_attempts_scenario_id",
        table_name="scenario_attempts",
    )

    op.drop_index(
        "ix_scenario_attempts_user_id",
        table_name="scenario_attempts",
    )

    op.drop_table("scenario_attempts")
