
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Integer,
    String,
    Text,
)

from data_and_integration_layer.database.connection import Base


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    category = Column(String, nullable=False)
    type = Column(String, nullable=False)
    difficulty = Column(String, nullable=False)
    instruction = Column(Text, nullable=False)
    content = Column(Text, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )
