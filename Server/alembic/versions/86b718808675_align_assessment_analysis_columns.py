"""align assessment analysis columns

Revision ID: 86b718808675
Revises: 8b08f5e5f599
Create Date: 2026-09-28
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "86b718808675"
down_revision: Union[str, Sequence[str], None] = "8b08f5e5f599"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade():
    # Fix task_analysis_results
    op.drop_constraint(
        "task_analysis_results_assessment_task_id_fkey",
        "task_analysis_results",
        type_="foreignkey",
    )

    op.drop_constraint(
        "task_analysis_results_assessment_task_id_key",
        "task_analysis_results",
        type_="unique",
    )

    op.drop_index(
        "ix_task_analysis_results_assessment_task_id",
        table_name="task_analysis_results",
    )

    op.drop_column(
        "task_analysis_results",
        "assessment_task_id",
    )

    # Fix speech_events
    op.drop_constraint(
        "speech_events_task_analysis_result_id_fkey",
        "speech_events",
        type_="foreignkey",
    )

    op.drop_index(
        "ix_speech_events_task_analysis_result_id",
        table_name="speech_events",
    )

    op.alter_column(
        "speech_events",
        "task_analysis_result_id",
        new_column_name="analysis_result_id",
    )

    op.create_foreign_key(
        "speech_events_analysis_result_id_fkey",
        "speech_events",
        "task_analysis_results",
        ["analysis_result_id"],
        ["id"],
    )

    op.create_index(
        "ix_speech_events_analysis_result_id",
        "speech_events",
        ["analysis_result_id"],
        unique=False,
    )
def downgrade():
    pass