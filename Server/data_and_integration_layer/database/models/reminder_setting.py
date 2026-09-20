from sqlalchemy import Boolean, Column, ForeignKey, Integer, Time
from sqlalchemy.orm import relationship

from data_and_integration_layer.database.connection import Base


class ReminderSetting(Base):
    __tablename__ = "reminder_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    enabled = Column(Boolean, nullable=False, default=True)
    reminder_time = Column(Time, nullable=False)

    user = relationship("User")