from sqlalchemy import Boolean, Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship

from data_and_integration_layer.database.connection import Base


class TrainingGoal(Base):
    __tablename__ = "training_goals"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    goal = Column(String(255), nullable=False)

    # Whether the user has completed this goal
    is_completed = Column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    # "manual" or "assessment"
    source = Column(
        String(20),
        nullable=False,
        default="manual",
        server_default="manual",
    )

    user = relationship("User")