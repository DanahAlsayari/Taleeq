from statistics import mean

from application_layer.assessment_analysis.task_analysis_service import (
    TaskAnalysisService,
)
from data_and_integration_layer.database.Repositories.assessment_repository import (
    AssessmentRepository,
)


class AssessmentAnalysisService:

    def __init__(self, db):
        self.repository = AssessmentRepository(db)
        self.task_analysis_service = TaskAnalysisService()

    def analyze_assessment(self, assessment_id: int):

        assessment = self.repository.get_assessment(
            assessment_id
        )

        if not assessment:
            raise ValueError("Assessment not found.")

        tasks = self.repository.get_assessment_tasks(
            assessment_id
        )

        if not tasks:
            raise ValueError("No tasks found for this assessment.")

        results = []

        for task in tasks:

            if not task.storage_url:
                continue

            try:
                analysis = self.task_analysis_service.analyze_task(
                    task.storage_url
                )

                saved_result = self.repository.save_task_analysis(
                    task,
                    analysis,
                )

                results.append(saved_result)

            except Exception as error:
                self.repository.mark_task_as_failed(
                    task,
                    str(error),
                )

        if not results:
            raise ValueError(
                "No assessment tasks were successfully analyzed."
            )

        overall_result = self._calculate_overall_result(
            results
        )

        self.repository.update_assessment_result(
            assessment_id,
            overall_result,
        )

        self.repository.update_fluency_profile(
            assessment.user_id,
            overall_result,
        )

        return overall_result

    def _calculate_overall_result(self, results):

        speaking_rates = [
            result.speaking_rate_wpm
            for result in results
            if result.speaking_rate_wpm is not None
        ]

        return {
            "stuttering_percent": mean(
                result.stuttering_percent
                for result in results
            ),
            "repetition_percent": mean(
                result.repetition_percent
                for result in results
            ),
            "prolongation_percent": mean(
                result.prolongation_percent
                for result in results
            ),
            "block_percent": mean(
                result.block_percent
                for result in results
            ),
            "speaking_rate_wpm": (
                mean(speaking_rates)
                if speaking_rates
                else None
            ),
            "speaking_rate": mean(
                result.speaking_rate
                for result in results
            ),
            "timing_pacing": mean(
                result.timing_pacing
                for result in results
            ),
        }