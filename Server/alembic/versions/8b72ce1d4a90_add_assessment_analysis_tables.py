"""add assessment analysis tables

Revision ID: 8b72ce1d4a90
Revises: f1346073ac16
Create Date: 2026-09-21 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "8b72ce1d4a90"
down_revision: Union[str, Sequence[str], None] = "f1346073ac16"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "assessments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("overall_stuttering_percent", sa.Float(), nullable=True),
        sa.Column("primary_pattern", sa.String(length=20), nullable=True),
        sa.Column("speaking_rate", sa.String(length=20), nullable=True),
        sa.Column("timing_pacing", sa.String(length=20), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_assessments_id"), "assessments", ["id"], unique=False)
    op.create_index(
        op.f("ix_assessments_status"), "assessments", ["status"], unique=False
    )
    op.create_index(
        op.f("ix_assessments_user_id"), "assessments", ["user_id"], unique=False
    )

    op.create_table(
        "assessment_tasks",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("assessment_id", sa.Integer(), nullable=False),
        sa.Column("task_type", sa.String(length=30), nullable=False),
        sa.Column("storage_url", sa.String(length=2048), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("analyzed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["assessment_id"], ["assessments.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("assessment_id", "task_type", name="uq_assessment_task_type"),
    )
    op.create_index(
        op.f("ix_assessment_tasks_assessment_id"),
        "assessment_tasks",
        ["assessment_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_assessment_tasks_id"), "assessment_tasks", ["id"], unique=False
    )
    op.create_index(
        op.f("ix_assessment_tasks_status"), "assessment_tasks", ["status"], unique=False
    )

    op.create_table(
        "task_analysis_results",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("assessment_task_id", sa.Integer(), nullable=False),
        sa.Column("stuttering_percent", sa.Float(), nullable=False),
        sa.Column("repetition_percent", sa.Float(), nullable=False),
        sa.Column("prolongation_percent", sa.Float(), nullable=False),
        sa.Column("block_percent", sa.Float(), nullable=False),
        sa.Column("speaking_rate_wpm", sa.Float(), nullable=True),
        sa.Column("speaking_rate", sa.String(length=20), nullable=False),
        sa.Column("timing_pacing", sa.String(length=20), nullable=False),
        sa.Column("raw_openai_response", sa.JSON(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["assessment_task_id"], ["assessment_tasks.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("assessment_task_id"),
    )
    op.create_index(
        op.f("ix_task_analysis_results_assessment_task_id"),
        "task_analysis_results",
        ["assessment_task_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_task_analysis_results_id"),
        "task_analysis_results",
        ["id"],
        unique=False,
    )

    op.create_table(
        "speech_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("task_analysis_result_id", sa.Integer(), nullable=False),
        sa.Column("event_type", sa.String(length=20), nullable=False),
        sa.Column("start_time_seconds", sa.Float(), nullable=False),
        sa.Column("end_time_seconds", sa.Float(), nullable=False),
        sa.Column("word_or_sound", sa.String(length=255), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(
            ["task_analysis_result_id"], ["task_analysis_results.id"]
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_speech_events_id"), "speech_events", ["id"], unique=False
    )
    op.create_index(
        op.f("ix_speech_events_task_analysis_result_id"),
        "speech_events",
        ["task_analysis_result_id"],
        unique=False,
    )

    op.create_table(
        "fluency_profiles",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("baseline_assessment_id", sa.Integer(), nullable=True),
        sa.Column("overall_stuttering_percent", sa.Float(), nullable=False),
        sa.Column("primary_pattern", sa.String(length=20), nullable=False),
        sa.Column("repetition_percent", sa.Float(), nullable=False),
        sa.Column("prolongation_percent", sa.Float(), nullable=False),
        sa.Column("block_percent", sa.Float(), nullable=False),
        sa.Column("speaking_rate", sa.String(length=20), nullable=False),
        sa.Column("timing_pacing", sa.String(length=20), nullable=False),
        sa.Column(
            "last_updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["baseline_assessment_id"], ["assessments.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index(
        op.f("ix_fluency_profiles_baseline_assessment_id"),
        "fluency_profiles",
        ["baseline_assessment_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_fluency_profiles_id"), "fluency_profiles", ["id"], unique=False
    )
    op.create_index(
        op.f("ix_fluency_profiles_user_id"),
        "fluency_profiles",
        ["user_id"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_fluency_profiles_user_id"), table_name="fluency_profiles")
    op.drop_index(op.f("ix_fluency_profiles_id"), table_name="fluency_profiles")
    op.drop_index(
        op.f("ix_fluency_profiles_baseline_assessment_id"),
        table_name="fluency_profiles",
    )
    op.drop_table("fluency_profiles")

    op.drop_index(
        op.f("ix_speech_events_task_analysis_result_id"), table_name="speech_events"
    )
    op.drop_index(op.f("ix_speech_events_id"), table_name="speech_events")
    op.drop_table("speech_events")

    op.drop_index(
        op.f("ix_task_analysis_results_id"), table_name="task_analysis_results"
    )
    op.drop_index(
        op.f("ix_task_analysis_results_assessment_task_id"),
        table_name="task_analysis_results",
    )
    op.drop_table("task_analysis_results")

    op.drop_index(op.f("ix_assessment_tasks_status"), table_name="assessment_tasks")
    op.drop_index(op.f("ix_assessment_tasks_id"), table_name="assessment_tasks")
    op.drop_index(
        op.f("ix_assessment_tasks_assessment_id"), table_name="assessment_tasks"
    )
    op.drop_table("assessment_tasks")

    op.drop_index(op.f("ix_assessments_user_id"), table_name="assessments")
    op.drop_index(op.f("ix_assessments_status"), table_name="assessments")
    op.drop_index(op.f("ix_assessments_id"), table_name="assessments")
    op.drop_table("assessments")
