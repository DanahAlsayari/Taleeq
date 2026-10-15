"""Add techniques table

Revision ID: 6882fcad7eb7
Revises: c4a7d1e9f203
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "6882fcad7eb7"
down_revision: Union[str, Sequence[str], None] = "c4a7d1e9f203"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "techniques",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name_ar", sa.String(length=100), nullable=False),
        sa.Column("name_en", sa.String(length=100), nullable=False),
        sa.Column("category", sa.String(length=50), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("steps", sa.JSON(), nullable=False),
        sa.Column("example", sa.Text(), nullable=True),
        sa.Column("tips", sa.JSON(), nullable=True),
        sa.Column("video_url", sa.Text(), nullable=True),
        sa.Column("video_source", sa.String(length=30), nullable=True),
        sa.Column("video_title", sa.String(length=150), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        op.f("ix_techniques_id"),
        "techniques",
        ["id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_techniques_id"),
        table_name="techniques",
    )

    op.drop_table("techniques")