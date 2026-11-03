"""add scenario tables

Revision ID: ba87e4728f8c
Revises: 639b33ee8dae
Create Date: 2026-11-03 04:25:07.868878

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'ba87e4728f8c'
down_revision: Union[str, Sequence[str], None] = '639b33ee8dae'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'scenarios',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(length=150), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('video_url', sa.Text(), nullable=True),
        sa.Column('conversation_start_time', sa.Float(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'scenario_difficulties',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('scenario_id', sa.UUID(), nullable=False),
        sa.Column('difficulty', sa.String(length=16), nullable=False),
        sa.Column('prompt', sa.Text(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.CheckConstraint(
            "difficulty IN ('easy', 'medium', 'hard')",
            name='ck_scenario_difficulty',
        ),
        sa.ForeignKeyConstraint(
            ['scenario_id'],
            ['scenarios.id'],
            ondelete='CASCADE',
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'scenario_id',
            'difficulty',
            name='uq_scenario_difficulty',
        ),
    )


def downgrade() -> None:
    op.drop_table('scenario_difficulties')
    op.drop_table('scenarios')
