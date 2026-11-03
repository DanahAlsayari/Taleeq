
from uuid import uuid4

from sqlalchemy import (
    Column,
    String,
    Text,
    Boolean,
    ForeignKey,
    UniqueConstraint,
    CheckConstraint,
)
from sqlalchemy.dialects.postgresql import UUID

from data_and_integration_layer.database.connection import Base


class ScenarioDifficulty(Base):
    __tablename__ = "scenario_difficulties"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    scenario_id = Column(
        UUID(as_uuid=True),
        ForeignKey("scenarios.id", ondelete="CASCADE"),
        nullable=False,
    )

    difficulty = Column(String(16), nullable=False)

    prompt = Column(Text, nullable=False)

    is_active = Column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint(
            "scenario_id",
            "difficulty",
            name="uq_scenario_difficulty",
        ),
        CheckConstraint(
            "difficulty IN ('easy', 'medium', 'hard')",
            name="ck_scenario_difficulty",
        ),
    )
