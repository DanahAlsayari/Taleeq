from datetime import time

from pydantic import BaseModel


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