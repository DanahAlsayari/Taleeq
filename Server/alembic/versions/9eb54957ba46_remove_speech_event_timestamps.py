"""remove speech event timestamps

Revision ID: 9eb54957ba46
Revises: d8ad960bf524
Create Date: 2026-09-28 22:50:49.962405

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9eb54957ba46'
down_revision: Union[str, Sequence[str], None] = 'd8ad960bf524'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade():
    op.drop_column(
        "speech_events",
        "start_time_seconds",
    )

    op.drop_column(
        "speech_events",
        "end_time_seconds",
    )


def downgrade():
    op.add_column(
        "speech_events",
        sa.Column(
            "start_time_seconds",
            sa.Float(),
            nullable=False,
        ),
    )

    op.add_column(
        "speech_events",
        sa.Column(
            "end_time_seconds",
            sa.Float(),
            nullable=False,
        ),
    )
