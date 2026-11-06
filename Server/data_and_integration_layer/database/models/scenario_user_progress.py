from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID

from data_and_integration_layer.database.connection import Base


class ScenarioUserProgress(Base):
    __tablename__ = "scenario_user_progress"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    scenario_id = Column(
        UUID(as_uuid=True),
        ForeignKey("scenarios.id"),
        nullable=False,
    )

    latest_attempt_id = Column(
        UUID(as_uuid=True),
        ForeignKey("scenario_attempts.id"),
        nullable=False,
    )

    best_attempt_id = Column(
        UUID(as_uuid=True),
        ForeignKey("scenario_attempts.id"),
        nullable=False,
    )

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "scenario_id",
            name="uq_scenario_user_progress",
        ),
    )