
from typing import Any
from uuid import UUID
from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.exercise_attempt import ExerciseAttempt


class ExerciseAttemptRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_previous_attempt(
        self,
        user_id: int,
        exercise_type: str,
        difficulty: str,
    ) -> ExerciseAttempt | None:

        return (
            self.db.query(ExerciseAttempt)
            .filter(
                ExerciseAttempt.user_id == user_id,
                ExerciseAttempt.exercise_type == exercise_type,
                ExerciseAttempt.difficulty == difficulty,
            )
            .order_by(
                ExerciseAttempt.created_at.desc(),
                ExerciseAttempt.id.desc(),
            )
            .first()
        )


    def get_last_five_attempts(
        self,
        user_id: int,
    )    -> list[ExerciseAttempt]:

        return (
            self.db.query(ExerciseAttempt)
            .filter(
                ExerciseAttempt.user_id == user_id,
            )
            .order_by(
                ExerciseAttempt.created_at.desc(),
                ExerciseAttempt.id.desc(),
            )
            .limit(5)
            .all()
        )

        
    def get_all_attempts(
        self,
        user_id: int,
    )    -> list[ExerciseAttempt]:

        return (
            self.db.query(ExerciseAttempt)
            .filter(
                ExerciseAttempt.user_id == user_id,
            )
            .order_by(
                ExerciseAttempt.created_at.desc(),
                ExerciseAttempt.id.desc(),
            )
            .all()
        )
    def save_attempt(
        self,
        user_id: int,
        exercise_id: UUID,
        exercise_type: str,
        difficulty: str,
        scores: dict[str, float],
        metrics: dict[str, float | None],
        feedback: dict[str, Any],
        audio_duration_seconds: int,
        raw_openai_response: dict[str, Any],
    ) -> ExerciseAttempt:

        attempt = ExerciseAttempt(
            user_id=user_id,
            exercise_id=exercise_id,
            exercise_type=exercise_type,
            difficulty=difficulty,

            fluency_score=scores["fluency_score"],
            rhythm_score=scores["rhythm_score"],
            speed_control_score=scores["speed_control_score"],
            task_adherence_score=scores["task_adherence_score"],
            total_score=scores["total_score"],

            stuttering_percent=metrics["stuttering_percent"],
            repetition_percent=metrics["repetition_percent"],
            prolongation_percent=metrics["prolongation_percent"],
            block_percent=metrics["block_percent"],
            speaking_rate_wpm=metrics.get("speaking_rate_wpm"),
            speaking_rate=metrics["speaking_rate"],
            timing_pacing=metrics["timing_pacing"],

            feedback=feedback,
            audio_duration_seconds=audio_duration_seconds,
            raw_openai_response=raw_openai_response,
        )

        self.db.add(attempt)
        self.db.commit()
        self.db.refresh(attempt)

        return attempt