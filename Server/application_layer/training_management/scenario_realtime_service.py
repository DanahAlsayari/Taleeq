import logging
import os

from openai import OpenAI, APIError, APIConnectionError, RateLimitError
from sqlalchemy.orm import Session

from data_and_integration_layer.database.Repositories.scenario_repository import (
    ScenarioRepository,
)
from application_layer.training_management.scenario_service import (
    ScenarioService,
)


logger = logging.getLogger(__name__)

REALTIME_MODEL = "gpt-realtime-1.5"

# Voice mapping for each scenario. If a scenario is not listed here, the default voice "cedar" will be used.
SCENARIO_VOICES = {
    "طلب قهوة": "cedar",
  
}


class ScenarioRealtimeService:

    def __init__(self, db: Session):
        self.repository = ScenarioRepository(db)
        self.scenario_service = ScenarioService(db)

    def complete_scenario(
        self,
        user_id: int,
        attempt_id,
        duration_seconds: int,
        end_reason: str,
        analysis_result: dict,
    ):
        attempt = self.repository.get_attempt_by_id(
            attempt_id=attempt_id,
            user_id=user_id,
        )
        if attempt is None or attempt.status != "in_progress":
            return None

        if not isinstance(analysis_result, dict):
            raise ValueError("Scenario analysis must be a JSON object.")

        scores = analysis_result.get("scores")
        if not isinstance(scores, dict):
            raise ValueError("Scenario analysis scores are missing.")

        for score_name in ("fluency_score", "rhythm_score"):
            score = scores.get(score_name)
            if score is not None and (
                isinstance(score, bool)
                or not isinstance(score, (int, float))
                or not 0 <= score <= 100
            ):
                raise ValueError(
                    f"{score_name} must be between 0 and 100 or null."
                )

        metrics = analysis_result.get("metrics")
        if metrics is not None:
            if not isinstance(metrics, dict):
                raise ValueError("Scenario analysis metrics must be an object.")

            for metric_name in (
                "stuttering_percent",
                "repetition_percent",
                "prolongation_percent",
                "block_percent",
            ):
                metric = metrics.get(metric_name)
                if metric is not None and (
                    isinstance(metric, bool)
                    or not isinstance(metric, (int, float))
                    or not 0 <= metric <= 100
                ):
                    raise ValueError(
                        f"{metric_name} must be between 0 and 100 or null."
                    )

            speaking_rate = metrics.get("speaking_rate_wpm")
            if speaking_rate is not None and (
                isinstance(speaking_rate, bool)
                or not isinstance(speaking_rate, (int, float))
                or speaking_rate < 0
            ):
                raise ValueError(
                    "speaking_rate_wpm must be zero or greater, or null."
                )

        progress = self.repository.get_user_progress(
            user_id=user_id,
            scenario_id=attempt.scenario_id,
        )
        is_best_attempt = progress is None

        if progress is not None:
            previous_best = self.repository.get_attempt_by_id(
                attempt_id=progress.best_attempt_id,
            )
            previous_result = (
                previous_best.analysis_result
                if previous_best and isinstance(previous_best.analysis_result, dict)
                else {}
            )
            previous_scores = previous_result.get("scores", {})
            new_fluency = scores.get("fluency_score")
            previous_fluency = (
                previous_scores.get("fluency_score")
                if isinstance(previous_scores, dict)
                else None
            )
            is_best_attempt = (
                isinstance(new_fluency, (int, float))
                and (
                    not isinstance(previous_fluency, (int, float))
                    or new_fluency >= previous_fluency
                )
            )

        completed = self.scenario_service.complete_scenario(
            user_id=user_id,
            attempt_id=attempt_id,
            duration_seconds=duration_seconds,
            end_reason=end_reason,
            analysis_result=analysis_result,
            is_best_attempt=is_best_attempt,
        )
        if completed is None:
            return None

        return {
            "attempt_id": str(completed.id),
            "scenario_id": str(completed.scenario_id),
            "duration_seconds": completed.duration_seconds,
            "end_reason": completed.end_reason,
            **analysis_result,
        }

    def create_session_token(
        self,
        user_id: int,
        attempt_id,
    ):
        # 1. Verify that the attempt belongs to the user.
        attempt = self.repository.get_attempt_by_id(
            attempt_id=attempt_id,
            user_id=user_id,
        )

        if attempt is None:
            return None

        if attempt.status != "in_progress":
            return None

        # 2. Retrieve the scenario.
        scenario = self.repository.get_scenario_by_id(
            attempt.scenario_id
        )

        if scenario is None or not scenario.is_active:
            return None

        # 3. Retrieve the selected difficulty and its prompt.
        difficulty = self.repository.get_difficulty_by_id(
            scenario_id=attempt.scenario_id,
            difficulty_id=attempt.scenario_difficulty_id,
        )

        if difficulty is None:
            return None

        if not difficulty.prompt or not difficulty.prompt.strip():
            raise ValueError("Scenario prompt is missing.")

        # 4. Select the scenario voice.
        voice = SCENARIO_VOICES.get(
            scenario.name,
            "cedar",
        )

        # 5. Get the API key from environment variables.
        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise ValueError("OPENAI_API_KEY is not configured.")

        # 6. Create an ephemeral client secret.
        client = OpenAI(api_key=api_key)

        database_prompt = difficulty.prompt.strip()

        language_and_role_rules = """
MANDATORY LANGUAGE AND ROLE RULES:
- Speak in natural Saudi colloquial Arabic (لهجة سعودية عامية) throughout the entire spoken conversation.
- Do not use English or formal Modern Standard Arabic unless the user explicitly requests it.
- The database scenario prompt is the source of truth for the assigned role, setting, objective, and difficulty.
- Stay in the exact assigned role and setting for the whole conversation. Never become a general assistant and never change the scenario.
- Start with a short, natural line that belongs to the assigned role and moves the scenario forward. Do not use unrelated generic greetings such as asking "How are you today?".
- Treat the user's messages as part of the role-play and respond naturally in character.
- Track whether the user has completed the scenario objective and whether all information or actions required by the scenario prompt have been obtained.
- As soon as the objective is fully completed, call the finish_scenario function instead of continuing small talk. Do not call it merely because the user gives a short answer; call it only when the scenario task is genuinely complete.
"""

        scenario_name = (scenario.name or "").strip().lower()
        if "قهوة" in scenario_name or "coffee" in scenario_name:
            language_and_role_rules += """
COFFEE SHOP ROLE LOCK:
- You are a BARISTA working at a coffee shop. You are not a customer, a receptionist, or a general assistant.
- Remain the barista for the entire conversation. The user is the customer.
- Open in Saudi colloquial Arabic with a barista greeting such as: "هلا والله، حياك! وش تحب تطلب؟"
- Continue by taking the customer's coffee order naturally. Ask only relevant questions when needed, such as drink choice, size, hot or iced, and milk preferences.
- Never start with an unrelated personal question such as "كيف حالك اليوم؟".
"""

        session_instructions = (
            f"{database_prompt}\n\n{language_and_role_rules.strip()}"
        )

        try:
            response = client.realtime.client_secrets.create(
                expires_after={
                    "anchor": "created_at",
                    "seconds": 600,
                },
                session={
                    "type": "realtime",
                    "model": REALTIME_MODEL,
                    "instructions": session_instructions,
                    "output_modalities": ["audio"],
                    "audio": {
                        "input": {
                            "noise_reduction": {
                                "type": "near_field",
                            },
                        "turn_detection": {
                            "type": "semantic_vad",
                            "eagerness": "high",
                        },
                        },
                        "output": {
                            "voice": voice,
                        },
                    },
                },
            )

        except (APIConnectionError, RateLimitError, APIError):
            logger.exception(
                "Failed to create Realtime session for attempt_id=%s",
                attempt_id,
            )
            raise

        logger.info(
            "Realtime session created for attempt_id=%s",
            attempt_id,
        )

        # Never return the main API key or the prompt to Flutter.
        return {
            "client_secret": response.value,
            "expires_at": response.expires_at,
            "session_id": response.session.id,
            "model": REALTIME_MODEL,
        }