"""add updated_at to fluency profiles

Revision ID: 7abe518e9819
Revises: 0d35605c5a49
Create Date: 2026-09-28 21:39:20.330939

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "7abe518e9819"
down_revision: Union[str, Sequence[str], None] = "0d35605c5a49"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "fluency_profiles",
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column(
        "fluency_profiles",
        "updated_at",
    )