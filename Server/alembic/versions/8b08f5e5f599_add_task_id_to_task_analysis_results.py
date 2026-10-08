"""add task_id to task analysis results

Revision ID: 8b08f5e5f599
Revises: 7abe518e9819
Create Date: 2026-09-28 22:25:03.461408
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "8b08f5e5f599"
down_revision: Union[str, Sequence[str], None] = "7abe518e9819"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "task_analysis_results",
        sa.Column(
            "task_id",
            sa.Integer(),
            nullable=False,
        ),
    )

    op.create_foreign_key(
        "fk_task_analysis_results_task_id",
        "task_analysis_results",
        "assessment_tasks",
        ["task_id"],
        ["id"],
    )

    op.create_unique_constraint(
        "uq_task_analysis_results_task_id",
        "task_analysis_results",
        ["task_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_task_analysis_results_task_id",
        "task_analysis_results",
        type_="unique",
    )

    op.drop_constraint(
        "fk_task_analysis_results_task_id",
        "task_analysis_results",
        type_="foreignkey",
    )

    op.drop_column(
        "task_analysis_results",
        "task_id",
    )