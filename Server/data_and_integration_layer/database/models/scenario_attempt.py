from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

from data_and_integration_layer.database.connection import Base


class ScenarioAttempt(Base):
    __tablename__ = "scenario_attempts"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    scenario_id = Column(
        UUID(as_uuid=True),
        ForeignKey("scenarios.id"),
        nullable=False,
        index=True,
    )

    scenario_difficulty_id = Column(
        UUID(as_uuid=True),
        ForeignKey("scenario_difficulties.id"),
        nullable=False,
    )

    status = Column(String(32), nullable=False)

    started_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )

    ended_at = Column(DateTime, nullable=True)

    duration_seconds = Column(Integer, nullable=True)

    end_reason = Column(String(40), nullable=True)

    analysis_result = Column(JSONB, nullable=True)

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )