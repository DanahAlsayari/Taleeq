"""add pre assessment submissions

Revision ID: bede9d4a5a5b
Revises: 0175fa4ff34b
Create Date: 2026-09-23 15:53:18.547675
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "bede9d4a5a5b"
down_revision: Union[str, Sequence[str], None] = "0175fa4ff34b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pre_assessment_submissions",
        sa.Column(
            "id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "answers",
            sa.JSON(),
            nullable=False,
        ),
        sa.Column(
            "submitted_at",
            sa.DateTime(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        op.f("ix_pre_assessment_submissions_id"),
        "pre_assessment_submissions",
        ["id"],
        unique=False,
    )

    op.create_index(
        op.f("ix_pre_assessment_submissions_user_id"),
        "pre_assessment_submissions",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_pre_assessment_submissions_user_id"),
        table_name="pre_assessment_submissions",
    )

    op.drop_index(
        op.f("ix_pre_assessment_submissions_id"),
        table_name="pre_assessment_submissions",
    )

    op.drop_table("pre_assessment_submissions")