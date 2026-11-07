
from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, String, Text, Boolean, Float
from sqlalchemy.dialects.postgresql import UUID

from data_and_integration_layer.database.connection import Base


class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    name = Column(String(150), nullable=False)

    description = Column(Text, nullable=True)

    instructions = Column(Text, nullable=True)

    video_url = Column(Text, nullable=True)

    # Time in seconds when the conversation starts
    conversation_start_time = Column(Float, nullable=True)

    is_active = Column(Boolean, nullable=False, default=True)

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
