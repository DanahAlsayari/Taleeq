from alembic import op


revision = "d8ad960bf524"
down_revision = "86b718808675"
branch_labels = None
depends_on = None


def upgrade():
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
    op.drop_constraint(
        "speech_events_analysis_result_id_fkey",
        "speech_events",
        type_="foreignkey",
    )

    op.drop_index(
        "ix_speech_events_analysis_result_id",
        table_name="speech_events",
    )

    op.alter_column(
        "speech_events",
        "analysis_result_id",
        new_column_name="task_analysis_result_id",
    )

    op.create_foreign_key(
        "speech_events_task_analysis_result_id_fkey",
        "speech_events",
        "task_analysis_results",
        ["task_analysis_result_id"],
        ["id"],
    )

    op.create_index(
        "ix_speech_events_task_analysis_result_id",
        "speech_events",
        ["task_analysis_result_id"],
        unique=False,
    )