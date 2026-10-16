from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

from data_and_integration_layer.database.connection import Base


class SpeechExercise(Base):
    __tablename__ = "speech_exercises"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    type = Column(String(32), nullable=False)
    title = Column(String(200), nullable=False)
    instructions = Column(Text, nullable=False)
    difficulty = Column(String(16), nullable=False)
    language = Column(String(10), nullable=False, default="ar")
    content = Column(JSONB, nullable=False)

    is_active = Column(Boolean, nullable=False, default=True)
    sort_order = Column(Integer, nullable=False)

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    __table_args__ = (
        CheckConstraint(
            '"type" IN ('
            "'Reading', 'Picture Description', "
            "'Question & Answer', 'Storytelling', "
            "'Free Speech')",
            name="ck_speech_exercises_type",
        ),
        CheckConstraint(
            "difficulty IN ('Easy', 'Medium', 'Hard')",
            name="ck_speech_exercises_difficulty",
        ),
        CheckConstraint(
            "sort_order >= 1",
            name="ck_speech_exercises_sort_order",
        ),
        UniqueConstraint(
            "type",
            "difficulty",
            "sort_order",
            name="uq_speech_exercises_type_difficulty_order",
        ),
        Index(
            "ix_speech_exercises_active_type_difficulty",
            "is_active",
            "type",
            "difficulty",
        ),
    )