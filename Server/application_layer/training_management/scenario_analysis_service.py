from io import BytesIO
from mutagen import File as MutagenFile
from sqlalchemy.orm import Session

from data_and_integration_layer.database.Repositories.scenario_repository import (
    ScenarioRepository,
)
from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
)
from application_layer.training_management.scenario_service import (
    ScenarioService,
)


class ScenarioAnalysisService:
    MIN_DURATION_SECONDS = 15
    MAX_DURATION_SECONDS = 300

    def __init__(self, db: Session):
        self.db = db
        self.repository = ScenarioRepository(db)
        self.audio_analyzer = OpenAIAudioAnalyzer()
        self.scenario_service = ScenarioService(db)

    @staticmethod
    def _get_audio_duration(audio_bytes: bytes) -> int:
        audio = MutagenFile(BytesIO(audio_bytes))
        if audio is None or audio.info is None:
            raise ValueError("تعذر تحديد مدة التسجيل الصوتي.")
        return max(1, round(audio.info.length))

    @staticmethod
    def _build_feedback(metrics: dict) -> dict:
        types = {
            "repetition_percent": (
                "التكرار",
                "حاولي بدء الكلمات بهدوء وعدم استعجال المقاطع.",
            ),
            "prolongation_percent": (
                "الإطالة",
                "تدرّبي على الانتقال السلس بين الأصوات دون إطالة غير مقصودة.",
            ),
            "block_percent": (
                "التوقف",
                "خذي وقتك لبدء الكلام بهدوء واستخدمي بداية صوتية مريحة.",
            ),
        }

        values = {
            key: float(metrics.get(key, 0.0) or 0.0)
            for key in types
        }

        if max(values.values(), default=0.0) <= 0:
            return {
                "strength": "لم تُرصد أحداث تأتأة في التسجيل، وحافظتِ على استمرارية الكلام.",
                "improvement": "استمري في ممارسة المحادثات الواقعية للمحافظة على طلاقتك.",
            }

        lowest_key = min(values, key=values.get)
        highest_key = max(values, key=values.get)
        lowest_name = types[lowest_key][0]

        strength = (
            f"كان {lowest_name} الأقل ظهورًا ضمن أنواع التأتأة المرصودة."
            if values[lowest_key] < values[highest_key]
            else "حافظتِ على نمط كلام متوازن خلال أجزاء من المحادثة."
        )

        improvement = types[highest_key][1]
        return {
            "strength": strength,
            "improvement": improvement,
        }

    def analyze_scenario(
        self,
        user_id: int,
        attempt_id,
        audio_bytes: bytes,
        audio_format: str,
        end_reason: str = "user_ended",
    ) -> dict:
        attempt = self.repository.get_attempt_by_id(
            attempt_id=attempt_id,
            user_id=user_id,
        )

        if attempt is None:
            raise LookupError("Scenario attempt not found.")

        if attempt.status != "in_progress":
            raise ValueError("هذه المحاولة ليست قيد التنفيذ.")

        duration_seconds = self._get_audio_duration(audio_bytes)

        if duration_seconds < self.MIN_DURATION_SECONDS:
            raise ValueError(
                "مدة التسجيل قصيرة جدًا. يرجى التحدث لمدة 15 ثانية على الأقل."
            )

        if duration_seconds > self.MAX_DURATION_SECONDS:
            raise ValueError(
                "تجاوز التسجيل الحد الأقصى المسموح به وهو 5 دقائق."
            )

        # Reuse the same validation and stuttering-analysis engine as Exercises.
        analysis = self.audio_analyzer.analyze_audio(
            audio_bytes=audio_bytes,
            audio_format=audio_format,
        )

        metrics = {
            "stuttering_percent": analysis.stuttering_percent,
            "repetition_percent": analysis.repetition_percent,
            "prolongation_percent": analysis.prolongation_percent,
            "block_percent": analysis.block_percent,
            "speaking_rate_wpm": analysis.speaking_rate_wpm,
            "speaking_rate": analysis.speaking_rate,
            "timing_pacing": analysis.timing_pacing,
        }

        # Scenario is a real-life conversation, not a structured exercise.
        # Therefore, do not generate exercise-only speed/task-adherence scores.
        scores = {
            "fluency_score": round(
                max(0.0, 100.0 - analysis.stuttering_percent), 2
            ),
            "rhythm_score": round(analysis.timing_pacing, 2),
        }

        feedback = self._build_feedback(metrics)
        speech_events = [
            event.model_dump()
            for event in analysis.speech_events
        ]

        analysis_result = {
            "scores": scores,
            "metrics": metrics,
            "feedback": feedback,
            "speech_events": speech_events,
        }

        progress = self.repository.get_user_progress(
            user_id=user_id,
            scenario_id=attempt.scenario_id,
        )

        is_best_attempt = True
        if progress is not None:
            previous_best = self.repository.get_attempt_by_id(
                attempt_id=progress.best_attempt_id
            )
            if previous_best and previous_best.analysis_result:
                previous_scores = previous_best.analysis_result.get("scores", {})
                previous_fluency = float(
                    previous_scores.get("fluency_score", 0.0)
                )
                is_best_attempt = (
                    scores["fluency_score"] >= previous_fluency
                )

        completed_attempt = self.scenario_service.complete_scenario(
            user_id=user_id,
            attempt_id=attempt_id,
            duration_seconds=duration_seconds,
            end_reason=end_reason,
            analysis_result=analysis_result,
            is_best_attempt=is_best_attempt,
        )

        if completed_attempt is None:
            raise ValueError("تعذر إكمال محاولة السيناريو.")

        return {
            "attempt_id": str(completed_attempt.id),
            "scenario_id": str(completed_attempt.scenario_id),
            "duration_seconds": duration_seconds,
            "end_reason": end_reason,
            **analysis_result,
        }
