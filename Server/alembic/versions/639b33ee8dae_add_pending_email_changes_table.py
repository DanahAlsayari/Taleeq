
"""add pending email changes table

Revision ID: 639b33ee8dae
Revises: b2ae56988ea0
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "639b33ee8dae"
down_revision: Union[str, Sequence[str], None] = "b2ae56988ea0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pending_email_changes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("new_email", sa.String(255), nullable=False),
        sa.Column("otp_digest", sa.String(64), nullable=False),
        sa.Column(
            "expires_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "failed_attempts",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "resend_count",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "last_sent_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
    )

    op.create_index(
        "ix_pending_email_changes_user_id",
        "pending_email_changes",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_pending_email_changes_user_id",
        table_name="pending_email_changes",
    )

    op.drop_table("pending_email_changes")
