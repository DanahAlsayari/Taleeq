
"""add profile picture path to users

Revision ID: b2ae56988ea0
Revises: f0d5dd903635
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b2ae56988ea0"
down_revision: Union[str, Sequence[str], None] = "f0d5dd903635"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "profile_picture_path",
            sa.String(length=255),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "profile_picture_path")
