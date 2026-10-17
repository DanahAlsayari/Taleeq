from sqlalchemy import Column, Integer, String, Text, JSON

from data_and_integration_layer.database.connection import Base


class Technique(Base):
    __tablename__ = "techniques"

    id = Column(Integer, primary_key=True, index=True)

    name_ar = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=False)

    category = Column(String(50), nullable=False)

    description = Column(Text, nullable=False)

    steps = Column(JSON, nullable=False)

    example = Column(Text, nullable=True)

    tips = Column(JSON, nullable=True)

    # Optional instructional video
    video_url = Column(Text, nullable=True)
    video_source = Column(String(30), nullable=True)
    video_title = Column(String(150), nullable=True)