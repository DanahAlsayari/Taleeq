from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, JSON
from sqlalchemy.orm import relationship

from data_and_integration_layer.database.connection import Base


class PreAssessmentSubmission(Base):
    __tablename__ = "pre_assessment_submissions"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    answers = Column(
        JSON,
        nullable=False,
    )

    submitted_at = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    user = relationship("User")