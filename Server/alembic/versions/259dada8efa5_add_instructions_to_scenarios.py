
"""add instructions to scenarios

Revision ID: 259dada8efa5
Revises: a94599c48ee0
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "259dada8efa5"
down_revision: Union[str, Sequence[str], None] = "a94599c48ee0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "scenarios",
        sa.Column("instructions", sa.Text(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("scenarios", "instructions")
