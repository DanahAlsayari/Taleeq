from sqlalchemy import (
    Column,
    DateTime,
    Integer,
    String,
)

from ..connection import Base


class PendingRegistration(Base):
    __tablename__ = "pending_registrations"

    id = Column(String(36), primary_key=True)

    name = Column(String(100), nullable=False)
    email = Column(String(255), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)
    phone_number = Column(String(20), nullable=False)
    age = Column(Integer, nullable=False)
    gender = Column(String(20), nullable=False)

    otp_digest = Column(String(64), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    failed_attempts = Column(Integer, nullable=False, default=0)
    resend_count = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime(timezone=True), nullable=False)
    last_sent_at = Column(DateTime(timezone=True), nullable=False)