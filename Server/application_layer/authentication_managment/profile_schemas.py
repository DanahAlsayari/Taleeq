from datetime import time

from pydantic import BaseModel , Field , field_validator
from .schemas import normalize_and_validate_name


class TrainingGoalCreate(BaseModel):
    goal: str


class TrainingGoalUpdate(BaseModel):
    goal: str | None = None
    is_completed: bool | None = None


class TrainingGoalOut(BaseModel):
    id: int
    goal: str
    is_completed: bool
    source: str

    class Config:
        from_attributes = True


class ReminderSettingUpdate(BaseModel):
    enabled: bool
    reminder_time: time


class ReminderSettingOut(BaseModel):
    enabled: bool
    reminder_time: time

    class Config:
        from_attributes = True


class ProfileOut(BaseModel):
    id: int
    name: str
    email: str
    profile_picture_url: str | None = None

class ProfileNameUpdate(BaseModel):
    name: str =Field(min_length=1, max_length=100) 
    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        return normalize_and_validate_name(value)
