"""Cascade user deletion to pre assessment submissions

Revision ID: 0045019b2c5f
Revises: 1084c33cb24a
Create Date: 2026-10-15 17:08:52.364711

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0045019b2c5f'
down_revision: Union[str, Sequence[str], None] = '1084c33cb24a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint(
        "pre_assessment_submissions_user_id_fkey",
        "pre_assessment_submissions",
        type_="foreignkey",
    )

    op.create_foreign_key(
        "pre_assessment_submissions_user_id_fkey",
        "pre_assessment_submissions",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint(
        "pre_assessment_submissions_user_id_fkey",
        "pre_assessment_submissions",
        type_="foreignkey",
    )

    op.create_foreign_key(
        "pre_assessment_submissions_user_id_fkey",
        "pre_assessment_submissions",
        "users",
        ["user_id"],
        ["id"],
    )
