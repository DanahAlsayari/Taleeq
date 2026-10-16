from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer,Text,Boolean, JSON
from sqlalchemy.orm import relationship

from data_and_integration_layer.database.connection import Base

from sqlalchemy.dialects.postgresql import ARRAY


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




class AssessmentQuestion(Base):
    __tablename__ = "assessment_questions"

    id = Column(Integer, primary_key=True, index=True)

    sort_order = Column(Integer, nullable=False)
    question = Column(Text, nullable=False)
    subtitle = Column(Text, nullable=False)
    multiple = Column(Boolean, nullable=False)
    options = Column(ARRAY(Text), nullable=False)

        