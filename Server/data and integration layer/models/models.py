from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    phone_number = Column(String, nullable=True)
    age = Column(Integer, nullable=True)
    gender = Column(String, nullable=True)

    assessments = relationship(
        "Assessment", back_populates="user", cascade="all, delete-orphan"
    )
    fluency_profile = relationship(
        "FluencyProfile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )


class Assessment(Base):
    """One complete assessment attempt, containing the three required tasks."""

    __tablename__ = "assessments"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="pending", index=True)

    # Populated only after all three tasks have been analyzed successfully.
    overall_stuttering_percent = Column(Float, nullable=True)
    primary_pattern = Column(String, nullable=True)
    speaking_rate = Column(String, nullable=True)
    timing_pacing = Column(String, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="assessments")
    tasks = relationship(
        "AssessmentTask", back_populates="assessment", cascade="all, delete-orphan"
    )
    baseline_fluency_profiles = relationship(
        "FluencyProfile", back_populates="baseline_assessment"
    )


class AssessmentTask(Base):
    """One Reading, Picture Description, or Free Speech assessment task."""

    __tablename__ = "assessment_tasks"
    __table_args__ = (
        UniqueConstraint("assessment_id", "task_type", name="uq_assessment_task_type"),
    )

    id = Column(Integer, primary_key=True, index=True)
    assessment_id = Column(
        Integer, ForeignKey("assessments.id"), nullable=False, index=True
    )
    task_type = Column(String, nullable=False)
    firebase_storage_path = Column(String, nullable=False)
    status = Column(String, nullable=False, default="pending", index=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    analyzed_at = Column(DateTime(timezone=True), nullable=True)

    assessment = relationship("Assessment", back_populates="tasks")
    analysis_result = relationship(
        "TaskAnalysisResult",
        back_populates="assessment_task",
        uselist=False,
        cascade="all, delete-orphan",
    )


class TaskAnalysisResult(Base):
    """Structured OpenAI analysis output for one assessment task."""

    __tablename__ = "task_analysis_results"

    id = Column(Integer, primary_key=True, index=True)
    assessment_task_id = Column(
        Integer,
        ForeignKey("assessment_tasks.id"),
        nullable=False,
        unique=True,
        index=True,
    )
    stuttering_percent = Column(Float, nullable=False)
    repetition_percent = Column(Float, nullable=False)
    prolongation_percent = Column(Float, nullable=False)
    block_percent = Column(Float, nullable=False)
    speaking_rate_wpm = Column(Float, nullable=True)
    speaking_rate = Column(String, nullable=False)
    timing_pacing = Column(String, nullable=False)
    raw_openai_response = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    assessment_task = relationship("AssessmentTask", back_populates="analysis_result")
    speech_events = relationship(
        "SpeechEvent", back_populates="task_analysis_result", cascade="all, delete-orphan"
    )


class SpeechEvent(Base):
    """A time-bounded repetition, prolongation, or block detected in a recording."""

    __tablename__ = "speech_events"

    id = Column(Integer, primary_key=True, index=True)
    task_analysis_result_id = Column(
        Integer, ForeignKey("task_analysis_results.id"), nullable=False, index=True
    )
    event_type = Column(String, nullable=False)
    start_time_seconds = Column(Float, nullable=False)
    end_time_seconds = Column(Float, nullable=False)
    word_or_sound = Column(String, nullable=True)
    confidence = Column(Float, nullable=True)

    task_analysis_result = relationship(
        "TaskAnalysisResult", back_populates="speech_events"
    )


class FluencyProfile(Base):
    """The user's current personalization baseline, initially set from assessment."""

    __tablename__ = "fluency_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True
    )
    baseline_assessment_id = Column(
        Integer, ForeignKey("assessments.id"), nullable=True, index=True
    )
    overall_stuttering_percent = Column(Float, nullable=False)
    primary_pattern = Column(String, nullable=False)
    repetition_percent = Column(Float, nullable=False)
    prolongation_percent = Column(Float, nullable=False)
    block_percent = Column(Float, nullable=False)
    speaking_rate = Column(String, nullable=False)
    timing_pacing = Column(String, nullable=False)
    last_updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user = relationship("User", back_populates="fluency_profile")
    baseline_assessment = relationship(
        "Assessment", back_populates="baseline_fluency_profiles"
    )
