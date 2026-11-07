"""add session results

Revision ID: c7e5a91d3b42
Revises: 259dada8efa5
Create Date: 2026-11-06 23:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "c7e5a91d3b42"
down_revision: Union[str, Sequence[str], None] = "259dada8efa5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "session_results",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("session_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("total_score", sa.Float(), nullable=False),
        sa.Column("fluency_score", sa.Float(), nullable=False),
        sa.Column("rhythm_score", sa.Float(), nullable=False),
        sa.Column("speed_control_score", sa.Float(), nullable=False),
        sa.Column("task_adherence_score", sa.Float(), nullable=False),
        sa.Column("stuttering_percent", sa.Float(), nullable=False),
        sa.Column("repetition_percent", sa.Float(), nullable=False),
        sa.Column("prolongation_percent", sa.Float(), nullable=False),
        sa.Column("block_percent", sa.Float(), nullable=False),
        sa.Column("exercise_count", sa.Integer(), nullable=False),
        sa.Column("previous_total_score", sa.Float(), nullable=True),
        sa.Column("score_change", sa.Float(), nullable=True),
        sa.Column(
            "feedback",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
        ),
        sa.Column(
            "technique_summary",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "exercise_count >= 1",
            name="ck_session_results_exercise_count",
        ),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["practice_sessions.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_id"),
    )
    op.create_index(
        op.f("ix_session_results_user_id"),
        "session_results",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_session_results_user_id"),
        table_name="session_results",
    )
    op.drop_table("session_results")
