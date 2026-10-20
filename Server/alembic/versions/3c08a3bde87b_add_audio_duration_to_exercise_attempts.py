"""add audio duration to exercise attempts

Revision ID: 3c08a3bde87b
Revises: 7833ac150203
Create Date: 2026-10-20 05:18:08.367380

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3c08a3bde87b'
down_revision: Union[str, Sequence[str], None] = '7833ac150203'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None



def upgrade() -> None:
    op.add_column(
        "exercise_attempts",
        sa.Column(
            "audio_duration_seconds",
            sa.Integer(),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column(
        "exercise_attempts",
        "audio_duration_seconds",
    )