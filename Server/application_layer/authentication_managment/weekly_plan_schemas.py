from datetime import date, datetime

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    model_validator,
)


class PracticeSessionInput(BaseModel):
    practice_date: date
    duration_minutes: int = Field(strict=True, gt=0, le=120)


class WeeklyPlanInput(BaseModel):
    week_start: date
    sessions: list[PracticeSessionInput] = Field(
        max_length=7,
    )

    @model_validator(mode="after")
    def validate_session_dates(self):
        dates = [
            session.practice_date
            for session in self.sessions
        ]

        if len(dates) != len(set(dates)):
            raise ValueError("لا يمكن اختيار اليوم نفسه أكثر من مرة.")

        for practice_date in dates:
            difference = (practice_date - self.week_start).days

            if difference < 0 or difference > 6:
                raise ValueError(
                    "يجب أن تكون جميع الجلسات ضمن الأسبوع المحدد."
                )

        return self


class PracticeCompletionInput(BaseModel):
    is_completed: bool = Field(strict=True)


class PracticeSessionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    practice_date: date
    duration_minutes: int
    is_completed: bool
    completed_at: datetime | None


class WeeklyPlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    week_start: date
    sessions: list[PracticeSessionOut]