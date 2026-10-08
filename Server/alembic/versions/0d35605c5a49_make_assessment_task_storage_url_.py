"""make assessment task storage url optional

Revision ID: 0d35605c5a49
Revises: bede9d4a5a5b
Create Date: 2026-09-28 20:45:52.995411

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0d35605c5a49"
down_revision: Union[str, Sequence[str], None] = "bede9d4a5a5b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "assessment_tasks",
        "storage_url",
        existing_type=sa.Text(),
        nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "assessment_tasks",
        "storage_url",
        existing_type=sa.Text(),
        nullable=False,
    )