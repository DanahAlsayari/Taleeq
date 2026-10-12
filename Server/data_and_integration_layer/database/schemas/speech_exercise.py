from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


ExerciseType = Literal[
    "Reading",
    "Picture Description",
    "Question & Answer",
    "Storytelling",
    "Free Speech",
]

Difficulty = Literal["Easy", "Medium", "Hard"]


class SpeechExerciseBase(BaseModel):
    type: ExerciseType
    title: str = Field(min_length=1, max_length=200)
    instructions: str
    difficulty: Difficulty
    language: str = "ar"
    content: dict
    sort_order: int = Field(ge=1)


class SpeechExerciseCreate(SpeechExerciseBase):
    pass


class SpeechExerciseResponse(SpeechExerciseBase):
    id: UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)