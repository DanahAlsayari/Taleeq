from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from data_and_integration_layer.database.connection import Base


class PracticeSession(Base):
    __tablename__ = "practice_sessions"

    id = Column(Integer, primary_key=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    assessment_id = Column(
        Integer,
        ForeignKey("assessments.id"),
        nullable=False,
    )

    planned_practice_session_id = Column(
        Integer,
        ForeignKey(
            "planned_practice_sessions.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        unique=True,
    )

    practice_date = Column(Date, nullable=False)

    # Assigned per user when the session is saved.
    sequence_number = Column(Integer, nullable=False)

    additional_session = Column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    # Copy the selected budget so later schedule edits don't rewrite history.
    target_duration_minutes = Column(Integer, nullable=True)

    status = Column(
        String(20),
        nullable=False,
        default="ready",
        server_default="ready",
    )

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    exercises = relationship(
        "PracticeSessionExercise",
        back_populates="session",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="PracticeSessionExercise.position",
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "sequence_number",
            name="uq_practice_sessions_user_sequence",
        ),
        CheckConstraint(
            "sequence_number >= 1",
            name="ck_practice_sessions_sequence",
        ),
        CheckConstraint(
            "target_duration_minutes IS NULL OR "
            "target_duration_minutes BETWEEN 1 AND 120",
            name="ck_practice_sessions_duration",
        ),
        CheckConstraint(
            "status IN ('ready', 'in_progress', 'completed', 'cancelled')",
            name="ck_practice_sessions_status",
        ),
    )


class PracticeSessionExercise(Base):
    __tablename__ = "practice_session_exercises"

    id = Column(Integer, primary_key=True)

    session_id = Column(
        Integer,
        ForeignKey("practice_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    exercise_id = Column(
        UUID(as_uuid=True),
        ForeignKey("speech_exercises.id"),
        nullable=False,
    )

    technique_id = Column(
        Integer,
        ForeignKey("techniques.id"),
        nullable=True,
    )

    position = Column(Integer, nullable=False)
    selection_role = Column(String(30), nullable=False)

    # Preserve the selected content and difficulty at creation time.
    exercise_snapshot = Column(JSONB, nullable=False)

    target_recording_seconds = Column(Integer, nullable=False)

    status = Column(
        String(20),
        nullable=False,
        default="pending",
        server_default="pending",
    )

    completed_at = Column(DateTime(timezone=True), nullable=True)

    session = relationship(
        "PracticeSession",
        back_populates="exercises",
    )

    __table_args__ = (
        UniqueConstraint(
            "session_id",
            "position",
            name="uq_session_exercises_position",
        ),
        UniqueConstraint(
            "session_id",
            "exercise_id",
            name="uq_session_exercises_exercise",
        ),
        CheckConstraint(
            "position >= 1",
            name="ck_session_exercises_position",
        ),
        CheckConstraint(
            "target_recording_seconds > 0",
            name="ck_session_exercises_recording_seconds",
        ),
        CheckConstraint(
            "status IN ('pending', 'in_progress', 'completed')",
            name="ck_session_exercises_status",
        ),
    )