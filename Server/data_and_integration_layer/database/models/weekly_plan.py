from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from ..connection import Base


class WeeklyPlan(Base):
    __tablename__ = "weekly_plans"

    id = Column(Integer, primary_key=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    week_start = Column(Date, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    sessions = relationship(
        "PlannedPracticeSession",
        back_populates="plan",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "week_start",
            name="uq_weekly_plans_user_week",
        ),
    )


class PlannedPracticeSession(Base):
    __tablename__ = "planned_practice_sessions"

    id = Column(Integer, primary_key=True)

    plan_id = Column(
        Integer,
        ForeignKey("weekly_plans.id", ondelete="CASCADE"),
        nullable=False,
    )

    practice_date = Column(Date, nullable=False)
    duration_minutes = Column(Integer, nullable=False)

    is_completed = Column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    completed_at = Column(
        DateTime(timezone=True),
        nullable=True,
    )

    plan = relationship(
        "WeeklyPlan",
        back_populates="sessions",
    )

    __table_args__ = (
        UniqueConstraint(
            "plan_id",
            "practice_date",
            name="uq_planned_practice_sessions_plan_date",
        ),
        CheckConstraint(
            "duration_minutes > 0",
            name="ck_planned_practice_sessions_positive_duration",
        ),
    )
class WeeklyPracticeSchedule(Base):
    __tablename__ = "weekly_practice_schedules"

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )

    sessions = Column(
        JSON,
        nullable=False,
        default=list,
    )

    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )