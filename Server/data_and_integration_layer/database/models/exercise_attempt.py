from datetime import datetime
from uuid import uuid4


from sqlalchemy import (
    Column,
    DateTime,
    Float,
    String,
    ForeignKey,
    Integer,
    Index,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

from data_and_integration_layer.database.connection import Base


class ExerciseAttempt(Base):
    __tablename__ = "exercise_attempts"

    ##assign an id to the attempt
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

    exercise_id=Column(
        UUID(as_uuid=True),
        ForeignKey("speech_exercises.id"),##existing exercise
        nullable=False,
    )


    audio_duration_seconds = Column(
        Integer,
        nullable=True,
    )

    exercise_type = Column(String(32), nullable=False)
    difficulty = Column(String(16),nullable=False)

    fluency_score = Column(Float, nullable=False)
    rhythm_score= Column(Float,nullable=False)
    speed_control_score=Column(Float,nullable=False)
    task_adherence_score = Column(Float,nullable=False)
    total_score=Column(Float,nullable=False)

    stuttering_percent = Column(Float, nullable=False)
    repetition_percent = Column(Float, nullable=False)
    prolongation_percent = Column(Float, nullable=False)
    block_percent = Column(Float, nullable=False)

    speaking_rate_wpm = Column(Float, nullable=True)
    speaking_rate = Column(Float, nullable=False)
    timing_pacing = Column(Float, nullable=False)

    feedback = Column(JSONB,nullable=False)
    raw_openai_response = Column(JSONB,nullable=False)

    created_at = Column(
        DateTime , 
        nullable=False,
        default=datetime.utcnow,
    )


    ## useful for comaprasion
    __table_args__ = (
        Index(
            "ix_exercise_attempts_user_type_difficulty_created",
            "user_id",
            "exercise_type",
            "difficulty",
            "created_at",
        ),
    )
