from datetime import datetime

from sqlalchemy.orm import Session

from data_and_integration_layer.ai_integration.openai_audio import (
    AudioAnalysisResult,
)
from data_and_integration_layer.database.models.assessment import (
    Assessment,
    AssessmentTask,
    TaskAnalysisResult,
    SpeechEvent,
    FluencyProfile,
)


class AssessmentRepository:

    def __init__(self, db: Session):
        self.db = db

    def get_task(self, task_id: int) -> AssessmentTask | None:
        return (
            self.db.query(AssessmentTask)
            .filter(AssessmentTask.id == task_id)
            .first()
        )

    def get_assessment_tasks(
        self,
        assessment_id: int,
    ) -> list[AssessmentTask]:

        return (
            self.db.query(AssessmentTask)
            .filter(
                AssessmentTask.assessment_id == assessment_id
            )
            .all()
        )

    def save_task_analysis(
        self,
        task: AssessmentTask,
        analysis: AudioAnalysisResult,
    ) -> TaskAnalysisResult:

        result = TaskAnalysisResult(
            task_id=task.id,
            stuttering_percent=analysis.stuttering_percent,
            repetition_percent=analysis.repetition_percent,
            prolongation_percent=analysis.prolongation_percent,
            block_percent=analysis.block_percent,
            speaking_rate_wpm=analysis.speaking_rate_wpm,
            speaking_rate=analysis.speaking_rate,
            timing_pacing=analysis.timing_pacing,
        )

        self.db.add(result)
        self.db.flush()

        for event in analysis.speech_events:
            speech_event = SpeechEvent(
                analysis_result_id=result.id,
                event_type=event.event_type,
                word_or_sound=event.word_or_sound,
                confidence=event.confidence,
            )

            self.db.add(speech_event)

        task.status = "analyzed"
        task.analyzed_at = datetime.utcnow()

        self.db.commit()
        self.db.refresh(result)

        return result

    def mark_task_as_failed(
        self,
        task: AssessmentTask,
        error_message: str,
    ) -> None:

        task.status = "failed"
        task.error_message = error_message

        self.db.commit()

    def update_assessment_result(
        self,
        assessment_id: int,
        overall_result: dict,
    ) -> Assessment:

        assessment = (
            self.db.query(Assessment)
            .filter(Assessment.id == assessment_id)
            .first()
        )

        if not assessment:
            raise ValueError(
                "Assessment not found."
            )

        assessment.overall_stuttering_percent = (
            overall_result["stuttering_percent"]
        )

        assessment.primary_pattern = self._get_primary_pattern(
            overall_result
        )

        assessment.speaking_rate = (
            overall_result["speaking_rate"]
        )

        assessment.timing_pacing = (
            overall_result["timing_pacing"]
        )

        assessment.status = "completed"
        assessment.completed_at = datetime.utcnow()

        self.db.commit()
        self.db.refresh(assessment)

        return assessment

    def _get_primary_pattern(
        self,
        overall_result: dict,
    ) -> str:

        patterns = {
            "repetition": overall_result["repetition_percent"],
            "prolongation": overall_result["prolongation_percent"],
            "block": overall_result["block_percent"],
        }

        return max(
            patterns,
            key=patterns.get,
        )
    def get_assessment(
    self,
    assessment_id: int,
    ) -> Assessment | None:

        return (
            self.db.query(Assessment)
            .filter(Assessment.id == assessment_id)
            .first()
        )


    def update_fluency_profile(
        self,
        user_id: int,
        overall_result: dict,
    ) -> FluencyProfile:

        profile = (
            self.db.query(FluencyProfile)
            .filter(FluencyProfile.user_id == user_id)
            .first()
        )

        primary_pattern = self._get_primary_pattern(
            overall_result
        )

        if profile:
            profile.overall_stuttering_percent = (
                overall_result["stuttering_percent"]
            )
            profile.primary_pattern = primary_pattern
            profile.repetition_percent = (
                overall_result["repetition_percent"]
            )
            profile.prolongation_percent = (
                overall_result["prolongation_percent"]
            )
            profile.block_percent = (
                overall_result["block_percent"]
            )
            profile.speaking_rate = (
                overall_result["speaking_rate"]
            )
            profile.timing_pacing = (
                overall_result["timing_pacing"]
            )
            profile.updated_at = datetime.utcnow()

        else:
            profile = FluencyProfile(
                user_id=user_id,
                overall_stuttering_percent=(
                    overall_result["stuttering_percent"]
                ),
                primary_pattern=primary_pattern,
                repetition_percent=(
                    overall_result["repetition_percent"]
                ),
                prolongation_percent=(
                    overall_result["prolongation_percent"]
                ),
                block_percent=(
                    overall_result["block_percent"]
                ),
                speaking_rate=(
                    overall_result["speaking_rate"]
                ),
                timing_pacing=(
                    overall_result["timing_pacing"]
                ),
                updated_at=datetime.utcnow(),
            )

            self.db.add(profile)

        self.db.commit()
        self.db.refresh(profile)

        return profile




    def get_fluency_profile(
        self,
        user_id: int,
    ) -> FluencyProfile | None:
        return (
            self.db.query(FluencyProfile)
            .filter(FluencyProfile.user_id == user_id)
            .first()
        )