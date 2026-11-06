"""Add personalized practice sessions

Revision ID: a94599c48ee0
Revises: 340e2fe1af57
Create Date: 2026-11-06 16:04:30.123963

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'a94599c48ee0'
down_revision: Union[str, Sequence[str], None] = '340e2fe1af57'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "practice_sessions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("assessment_id", sa.Integer(), nullable=False),
        sa.Column(
            "planned_practice_session_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column("practice_date", sa.Date(), nullable=False),
        sa.Column("sequence_number", sa.Integer(), nullable=False),
        sa.Column(
            "additional_session",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column(
            "target_duration_minutes",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "status",
            sa.String(20),
            server_default=sa.text("'ready'"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["assessment_id"],
            ["assessments.id"],
        ),
        sa.ForeignKeyConstraint(
            ["planned_practice_session_id"],
            ["planned_practice_sessions.id"],
            ondelete="SET NULL",
        ),
        sa.UniqueConstraint("planned_practice_session_id"),
        sa.UniqueConstraint(
            "user_id",
            "sequence_number",
            name="uq_practice_sessions_user_sequence",
        ),
        sa.CheckConstraint(
            "sequence_number >= 1",
            name="ck_practice_sessions_sequence",
        ),
        sa.CheckConstraint(
            "target_duration_minutes IS NULL OR "
            "target_duration_minutes BETWEEN 1 AND 120",
            name="ck_practice_sessions_duration",
        ),
        sa.CheckConstraint(
            "status IN ('ready', 'in_progress', 'completed', 'cancelled')",
            name="ck_practice_sessions_status",
        ),
    )

    op.create_index(
        "ix_practice_sessions_user_id",
        "practice_sessions",
        ["user_id"],
    )

    op.create_table(
        "practice_session_exercises",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("session_id", sa.Integer(), nullable=False),
        sa.Column("exercise_id", sa.UUID(), nullable=False),
        sa.Column("technique_id", sa.Integer(), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("selection_role", sa.String(30), nullable=False),
        sa.Column(
            "exercise_snapshot",
            postgresql.JSONB(),
            nullable=False,
        ),
        sa.Column(
            "target_recording_seconds",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(20),
            server_default=sa.text("'pending'"),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["practice_sessions.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["exercise_id"],
            ["speech_exercises.id"],
        ),
        sa.ForeignKeyConstraint(
            ["technique_id"],
            ["techniques.id"],
        ),
        sa.UniqueConstraint(
            "session_id",
            "position",
            name="uq_session_exercises_position",
        ),
        sa.UniqueConstraint(
            "session_id",
            "exercise_id",
            name="uq_session_exercises_exercise",
        ),
        sa.CheckConstraint(
            "position >= 1",
            name="ck_session_exercises_position",
        ),
        sa.CheckConstraint(
            "target_recording_seconds > 0",
            name="ck_session_exercises_recording_seconds",
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'in_progress', 'completed')",
            name="ck_session_exercises_status",
        ),
    )

    op.create_index(
        "ix_practice_session_exercises_session_id",
        "practice_session_exercises",
        ["session_id"],
    )

    op.add_column(
        "exercise_attempts",
        sa.Column("session_exercise_id", sa.Integer(), nullable=True),
    )

    op.create_foreign_key(
        "fk_exercise_attempts_session_exercise_id",
        "exercise_attempts",
        "practice_session_exercises",
        ["session_exercise_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_index(
        "ix_exercise_attempts_session_exercise_id",
        "exercise_attempts",
        ["session_exercise_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_exercise_attempts_session_exercise_id",
        table_name="exercise_attempts",
    )

    op.drop_constraint(
        "fk_exercise_attempts_session_exercise_id",
        "exercise_attempts",
        type_="foreignkey",
    )

    op.drop_column("exercise_attempts", "session_exercise_id")

    op.drop_index(
        "ix_practice_session_exercises_session_id",
        table_name="practice_session_exercises",
    )
    op.drop_table("practice_session_exercises")

    op.drop_index(
        "ix_practice_sessions_user_id",
        table_name="practice_sessions",
    )
    op.drop_table("practice_sessions")
