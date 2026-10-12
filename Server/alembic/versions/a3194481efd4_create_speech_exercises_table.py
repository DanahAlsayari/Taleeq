"""create speech exercises table

Revision ID: a3194481efd4
Revises: 6882fcad7eb7
Create Date: 2026-10-12 15:26:04.828872

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "a3194481efd4"
down_revision: Union[str, Sequence[str], None] = "6882fcad7eb7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "speech_exercises",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("type", sa.String(length=32), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("instructions", sa.Text(), nullable=False),
        sa.Column("difficulty", sa.String(length=16), nullable=False),
        sa.Column(
            "language",
            sa.String(length=10),
            nullable=False,
        ),
        sa.Column(
            "content",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
        ),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            '"type" IN ('
            "'Reading', 'Picture Description', "
            "'Question & Answer', 'Storytelling', "
            "'Free Speech')",
            name="ck_speech_exercises_type",
        ),
        sa.CheckConstraint(
            "difficulty IN ('Easy', 'Medium', 'Hard')",
            name="ck_speech_exercises_difficulty",
        ),
        sa.CheckConstraint(
            "sort_order >= 1",
            name="ck_speech_exercises_sort_order",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "type",
            "difficulty",
            "sort_order",
            name="uq_speech_exercises_type_difficulty_order",
        ),
    )

    op.create_index(
        "ix_speech_exercises_active_type_difficulty",
        "speech_exercises",
        ["is_active", "type", "difficulty"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_speech_exercises_active_type_difficulty",
        table_name="speech_exercises",
    )
    op.drop_table("speech_exercises")