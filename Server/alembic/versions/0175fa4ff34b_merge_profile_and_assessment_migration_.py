"""merge profile and assessment migration heads

Revision ID: 0175fa4ff34b
Revises: 6dffe160999c, 8b72ce1d4a90
Create Date: 2026-09-23 15:49:09.069243

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0175fa4ff34b'
down_revision: Union[str, Sequence[str], None] = ('6dffe160999c', '8b72ce1d4a90')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
