import logging
import os

from openai import OpenAI, APIError, APIConnectionError, RateLimitError
from sqlalchemy.orm import Session

from data_and_integration_layer.database.Repositories.scenario_repository import (
    ScenarioRepository,
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

        try:
            response = client.realtime.client_secrets.create(
                expires_after={
                    "anchor": "created_at",
                    "seconds": 600,
                },
                session={
                    "type": "realtime",
                    "model": REALTIME_MODEL,
                    "instructions": difficulty.prompt,
                    "output_modalities": ["audio"],
                    "audio": {
                        "input": {
                            "noise_reduction": {
                                "type": "near_field",
                            },
                        "turn_detection": {
                            "type": "semantic_vad",
                            "eagerness": "low",
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