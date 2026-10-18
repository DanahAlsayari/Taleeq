"""create exercise attempts table

Revision ID: 7833ac150203
Revises: 0045019b2c5f
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "7833ac150203"
down_revision: Union[str, Sequence[str], None] = "0045019b2c5f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "exercise_attempts",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("exercise_id", sa.UUID(), nullable=False),
        sa.Column("exercise_type", sa.String(length=32), nullable=False),
        sa.Column("difficulty", sa.String(length=16), nullable=False),
        sa.Column("fluency_score", sa.Float(), nullable=False),
        sa.Column("rhythm_score", sa.Float(), nullable=False),
        sa.Column("speed_control_score", sa.Float(), nullable=False),
        sa.Column("task_adherence_score", sa.Float(), nullable=False),
        sa.Column("total_score", sa.Float(), nullable=False),
        sa.Column("stuttering_percent", sa.Float(), nullable=False),
        sa.Column("repetition_percent", sa.Float(), nullable=False),
        sa.Column("prolongation_percent", sa.Float(), nullable=False),
        sa.Column("block_percent", sa.Float(), nullable=False),
        sa.Column("speaking_rate_wpm", sa.Float(), nullable=True),
        sa.Column("speaking_rate", sa.Float(), nullable=False),
        sa.Column("timing_pacing", sa.Float(), nullable=False),
        sa.Column("feedback", postgresql.JSONB(), nullable=False),
        sa.Column("raw_openai_response", postgresql.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["exercise_id"], ["speech_exercises.id"]
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"]
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_exercise_attempts_user_id",
        "exercise_attempts",
        ["user_id"],
        unique=False,
    )

    op.create_index(
        "ix_exercise_attempts_user_type_difficulty_created",
        "exercise_attempts",
        ["user_id", "exercise_type", "difficulty", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_exercise_attempts_user_type_difficulty_created",
        table_name="exercise_attempts",
    )

    op.drop_index(
        "ix_exercise_attempts_user_id",
        table_name="exercise_attempts",
    )

    op.drop_table("exercise_attempts")