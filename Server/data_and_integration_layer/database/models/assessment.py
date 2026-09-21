from datetime import datetime

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from data_and_integration_layer.database.connection import Base


class Assessment(Base):
    __tablename__ = "assessments"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)

    status = Column(String, nullable=False, default="PENDING")

    overall_stuttering_percent = Column(Float, nullable=True)
    primary_pattern = Column(String, nullable=True)
    speaking_rate = Column(String, nullable=True)
    timing_pacing = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)

    tasks = relationship(
        "AssessmentTask",
        back_populates="assessment",
        cascade="all, delete-orphan",
    )


class AssessmentTask(Base):
    __tablename__ = "assessment_tasks"

    id = Column(Integer, primary_key=True, index=True)

    assessment_id = Column(
        Integer,
        ForeignKey("assessments.id"),
        nullable=False,
    )

    task_type = Column(String, nullable=False)

    storage_url = Column(Text, nullable=False)

    status = Column(
        String,
        nullable=False,
        default="PENDING",
    )

    error_message = Column(Text, nullable=True)

    analyzed_at = Column(DateTime, nullable=True)

    assessment = relationship(
        "Assessment",
        back_populates="tasks",
    )

    analysis_result = relationship(
        "TaskAnalysisResult",
        back_populates="task",
        uselist=False,
        cascade="all, delete-orphan",
    )


class TaskAnalysisResult(Base):
    __tablename__ = "task_analysis_results"

    id = Column(Integer, primary_key=True, index=True)

    task_id = Column(
        Integer,
        ForeignKey("assessment_tasks.id"),
        nullable=False,
        unique=True,
    )

    stuttering_percent = Column(Float, nullable=False)

    repetition_percent = Column(Float, nullable=False)
    prolongation_percent = Column(Float, nullable=False)
    block_percent = Column(Float, nullable=False)

    speaking_rate_wpm = Column(Float, nullable=True)
    speaking_rate = Column(String, nullable=True)
    timing_pacing = Column(String, nullable=True)

    task = relationship(
        "AssessmentTask",
        back_populates="analysis_result",
    )

    speech_events = relationship(
        "SpeechEvent",
        back_populates="analysis_result",
        cascade="all, delete-orphan",
    )


class SpeechEvent(Base):
    __tablename__ = "speech_events"

    id = Column(Integer, primary_key=True, index=True)

    analysis_result_id = Column(
        Integer,
        ForeignKey("task_analysis_results.id"),
        nullable=False,
    )

    event_type = Column(String, nullable=False)

    word_or_sound = Column(String, nullable=True)

    confidence = Column(Float, nullable=True)

    analysis_result = relationship(
        "TaskAnalysisResult",
        back_populates="speech_events",
    )


class FluencyProfile(Base):
    __tablename__ = "fluency_profiles"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        nullable=False,
        unique=True,
    )

    overall_stuttering_percent = Column(Float, nullable=True)

    primary_pattern = Column(String, nullable=True)

    repetition_percent = Column(Float, nullable=True)
    prolongation_percent = Column(Float, nullable=True)
    block_percent = Column(Float, nullable=True)

    speaking_rate = Column(String, nullable=True)
    timing_pacing = Column(String, nullable=True)

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )