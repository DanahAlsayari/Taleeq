
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String

from ..connection import Base


class PendingEmailChange(Base):
    __tablename__ = "pending_email_changes"

    id = Column(String(36), primary_key=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    new_email = Column(String(255), nullable=False)

    otp_digest = Column(String(64), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    failed_attempts = Column(Integer, nullable=False, default=0)
    resend_count = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime(timezone=True), nullable=False)
    last_sent_at = Column(DateTime(timezone=True), nullable=False)
