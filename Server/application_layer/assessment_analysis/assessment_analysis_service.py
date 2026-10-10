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

    # ---------------------------------------------------------
    # OLD FLOW
    # ---------------------------------------------------------

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
                print(
                    f"❌ Task {task.id} failed: {error}"
                )

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

    # ---------------------------------------------------------
    # NEW FLOW - DIRECT AUDIO
    # ---------------------------------------------------------

    def analyze_audio_tasks(
        self,
        assessment_id: int,
        audio_tasks: list[tuple[str, bytes, str]],
    ):

        assessment = self.repository.get_assessment(
            assessment_id
        )

        if not assessment:
            raise ValueError("Assessment not found.")

        if not audio_tasks:
            raise ValueError("No audio files were provided.")

        results = []

        for task_type, audio_bytes, audio_format in audio_tasks:

            try:
                print(
                    f"🎙️ ANALYZING {task_type} "
                    f"({audio_format})"
                )

                analysis = (
                    self.task_analysis_service.analyze_audio_bytes(
                        audio_bytes,
                        audio_format,
                    )
                )

                # Create/get the assessment task
                task = self.repository.get_or_create_task(
                    assessment_id=assessment_id,
                    task_type=task_type,
                )

                saved_result = self.repository.save_task_analysis(
                    task,
                    analysis,
                )

                results.append(saved_result)

            except Exception as error:

                print(
                    f"❌ {task_type} failed: {error}"
                )

                raise ValueError(
                    f"Failed to analyze {task_type}: {error}"
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

        task_results = []

        for (task_type, _, _), saved_result in zip(audio_tasks, results):

            patterns = {
                "repetition": saved_result.repetition_percent,
                "prolongation": saved_result.prolongation_percent,
                "block": saved_result.block_percent,
            }

            primary_pattern = max(patterns, key=patterns.get)

            task_results.append({
                "task_type": task_type,
                "pattern": primary_pattern,
                "percent": patterns[primary_pattern],
                "stuttering_percent": saved_result.stuttering_percent,
            })

        return {
            **overall_result,
            "task_results": task_results,
        }

    # ---------------------------------------------------------
    # CALCULATE OVERALL RESULT
    # ---------------------------------------------------------

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
            "speaking_rate": results[0].speaking_rate,
            "timing_pacing": results[0].timing_pacing,
        }