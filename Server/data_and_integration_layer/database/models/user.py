from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship

from ..connection import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    phone_number = Column(String(20), nullable=False)
    age = Column(Integer, nullable=False)
    gender = Column(String(20), nullable=False)

    assessments = relationship(
        "Assessment", back_populates="user", cascade="all, delete-orphan"
    )
    fluency_profile = relationship(
        "FluencyProfile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
