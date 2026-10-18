from datetime import datetime
from uuid import UUID
from typing import Literal

from fastapi import APIRouter, Depends, Query, File, UploadFile, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.speech_exercise import (
    SpeechExercise,
)


class SpeechExerciseResponse(BaseModel):
    id: UUID
    type: str
    title: str
    instructions: str
    difficulty: str
    language: str
    content: dict
    is_active: bool
    sort_order: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


router = APIRouter(
    prefix="/speech-exercises",
    tags=["Speech Exercises"],
)


@router.get("/", response_model=list[SpeechExerciseResponse])
def get_speech_exercises(
    type: Literal[
        "Reading",
        "Picture Description",
        "Question & Answer",
        "Storytelling",
        "Free Speech",
    ] | None = Query(default=None),
    difficulty: Literal["Easy", "Medium", "Hard"] | None = Query(
        default=None
    ),
    db: Session = Depends(get_db),
):
    query = db.query(SpeechExercise).filter(
        SpeechExercise.is_active.is_(True)
    )

    if type is not None:
        query = query.filter(SpeechExercise.type == type)

    if difficulty is not None:
        query = query.filter(SpeechExercise.difficulty == difficulty)

    return query.order_by(SpeechExercise.sort_order).all()


