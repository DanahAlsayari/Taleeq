"""add goal completion and source

Revision ID: b926f16d7260
Revises: 3c08a3bde87b
Create Date: 2026-10-21 06:27:07.351705

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b926f16d7260"
down_revision: Union[str, Sequence[str], None] = "3c08a3bde87b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add completion status and source to training goals."""

    # Add completion status
    op.add_column(
        "training_goals",
        sa.Column(
            "is_completed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )

    # Add goal source
    op.add_column(
        "training_goals",
        sa.Column(
            "source",
            sa.String(length=20),
            nullable=False,
            server_default="manual",
        ),
    )


def downgrade() -> None:
    """Remove completion status and source from training goals."""

    op.drop_column("training_goals", "source")

    op.drop_column("training_goals", "is_completed")