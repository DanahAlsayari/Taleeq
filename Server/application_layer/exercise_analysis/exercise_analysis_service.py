
from uuid import UUID

from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.speech_exercise import (
    SpeechExercise,
)
from data_and_integration_layer.database.Repositories.exercise_attempt_repository import (
    ExerciseAttemptRepository,
)
from data_and_integration_layer.ai_integration.openai_exercise import (
    OpenAIExerciseAnalyzer,
)


class ExerciseAnalysisService:

    def __init__(self, db: Session):
        self.db = db
        self.repository = ExerciseAttemptRepository(db)
        self.audio_analyzer = OpenAIExerciseAnalyzer()

    # ---------------------------------------------------------
    # ANALYZE EXERCISE
    # ---------------------------------------------------------

    def analyze_exercise(
        self,
        user_id: int,
        exercise_id: UUID,
        audio_bytes: bytes,
        audio_format: str,
    ):

        #find exercise
        exercise = (
            self.db.query(SpeechExercise)
            .filter(
                SpeechExercise.id == exercise_id,
                SpeechExercise.is_active.is_(True),
            )
            .first()
        )

        if not exercise:
            raise ValueError("Exercise not found.")

        #analyze
        analysis = self.audio_analyzer.analyze_audio(
            audio_bytes=audio_bytes,
            audio_format=audio_format,
            exercise_type=exercise.type,
            difficulty=exercise.difficulty,
            content=exercise.content,
            instructions=exercise.instructions,
        )

    
        total_score = self._calculate_total_score(analysis)


        previous_attempt = self.repository.get_previous_attempt(
            user_id=user_id,
            exercise_type=exercise.type,
            difficulty=exercise.difficulty,
        )


        scores = {
            "fluency_score": analysis.fluency_score,
            "rhythm_score": analysis.rhythm_score,
            "speed_control_score": analysis.speed_control_score,
            "task_adherence_score": analysis.task_adherence_score,
            "total_score": total_score,
        }


        metrics = {
            "stuttering_percent": analysis.stuttering_percent,
            "repetition_percent": analysis.repetition_percent,
            "prolongation_percent": analysis.prolongation_percent,
            "block_percent": analysis.block_percent,
            "speaking_rate_wpm": analysis.speaking_rate_wpm,
            "speaking_rate": analysis.speaking_rate,
            "timing_pacing": analysis.timing_pacing,
        }

        #Save 
        saved_attempt = self.repository.save_attempt(
            user_id=user_id,
            exercise_id=exercise_id,
            exercise_type=exercise.type,
            difficulty=exercise.difficulty,
            scores=scores,
            metrics=metrics,
            feedback=analysis.feedback,
            raw_openai_response=analysis.raw_openai_response,
        )

        #Compare
        previous_score = (
            previous_attempt.total_score
            if previous_attempt is not None
            else None
        )

        score_change = (
            round(total_score - previous_score, 2)
            if previous_score is not None
            else None
        )

        
        return {
            "attempt_id": str(saved_attempt.id),
            "exercise_id": str(exercise_id),
            "exercise_type": exercise.type,
            "difficulty": exercise.difficulty,
            "scores": scores,
            "metrics": metrics,
            "feedback": analysis.feedback,
            "speech_events": [
                event.model_dump()
                for event in analysis.speech_events
            ],
            "comparison": {
                "previous_score": previous_score,
                "current_score": total_score,
                "score_change": score_change,
            },
        }

    # ---------------------------------------------------------
    # CALCULATE TOTAL SCORE
    # ---------------------------------------------------------

    def _calculate_total_score(self, analysis) -> float:

        total_score = (
            analysis.fluency_score * 0.40
            + analysis.rhythm_score * 0.25
            + analysis.speed_control_score * 0.15
            + analysis.task_adherence_score * 0.20
        )

        return round(total_score, 2)