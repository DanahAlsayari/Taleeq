from sqlalchemy import Column, Integer, String, ForeignKey
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

    user = relationship("User")