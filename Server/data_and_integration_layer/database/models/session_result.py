from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB

from data_and_integration_layer.database.connection import Base


class SessionResult(Base):
    """Result of a completed practice session. One row per session."""

    __tablename__ = "session_results"

    id = Column(Integer, primary_key=True)

    session_id = Column(
        Integer,
        ForeignKey("practice_sessions.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    total_score = Column(Float, nullable=False)

    fluency_score = Column(Float, nullable=False)
    rhythm_score = Column(Float, nullable=False)
    speed_control_score = Column(Float, nullable=False)
    task_adherence_score = Column(Float, nullable=False)

    stuttering_percent = Column(Float, nullable=False)
    repetition_percent = Column(Float, nullable=False)
    prolongation_percent = Column(Float, nullable=False)
    block_percent = Column(Float, nullable=False)

    exercise_count = Column(Integer, nullable=False)

    # Comparison with the user's previous completed session.
    previous_total_score = Column(Float, nullable=True)
    score_change = Column(Float, nullable=True)

    # {"strength": "...", "improvement": "..."}
    feedback = Column(JSONB, nullable=False)

    # {"exercises_with_technique": n, "applied": n, "partial": n,
    #  "not_applied": n}
    technique_summary = Column(JSONB, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    __table_args__ = (
        CheckConstraint(
            "exercise_count >= 1",
            name="ck_session_results_exercise_count",
        ),
    )
