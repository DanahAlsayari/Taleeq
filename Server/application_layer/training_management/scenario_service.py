import logging
from uuid import UUID

from sqlalchemy.orm import Session

from data_and_integration_layer.database.Repositories.scenario_repository import (
    ScenarioRepository,
)


logger = logging.getLogger(__name__)


class ScenarioService:

    IN_PROGRESS = "in_progress"

    def __init__(self, db: Session):
        self.repository = ScenarioRepository(db)

    # =========================
    # Scenarios
    # =========================

    def get_active_scenarios(self):
        logger.info("Fetching active scenarios")

        scenarios = self.repository.get_active_scenarios()

        logger.info("Fetched %d active scenarios", len(scenarios))

        return scenarios

    def get_scenario_details(self, scenario_id: UUID):
        logger.info("Fetching scenario_id=%s", scenario_id)

        scenario = self.repository.get_scenario_by_id(scenario_id)

        if scenario is None or not scenario.is_active:
            logger.warning("Scenario not found or inactive: %s", scenario_id)
            return None

        difficulties = self.repository.get_active_difficulties(
            scenario_id
        )

        return {
            "scenario": scenario,
            "difficulties": difficulties,
        }

    # =========================
    # Start Scenario
    # =========================

    def start_scenario(
        self,
        user_id: int,
        scenario_id: UUID,
        difficulty_id: UUID,
    ):
        logger.info(
            "Starting scenario for user_id=%s, scenario_id=%s",
            user_id,
            scenario_id,
        )

        scenario = self.repository.get_scenario_by_id(scenario_id)

        if scenario is None or not scenario.is_active:
            logger.warning("Cannot start inactive or missing scenario")
            return None

        difficulty = self.repository.get_difficulty_by_id(
            scenario_id,
            difficulty_id,
        )

        if difficulty is None:
            logger.warning(
                "Invalid difficulty_id=%s for scenario_id=%s",
                difficulty_id,
                scenario_id,
            )
            return None

        attempt = self.repository.create_attempt(
            user_id=user_id,
            scenario_id=scenario_id,
            scenario_difficulty_id=difficulty_id,
            status=self.IN_PROGRESS,
        )

        logger.info("Scenario attempt created: %s", attempt.id)

        return attempt

    # =========================
    # Get Attempt
    # =========================

    def get_user_attempt(
        self,
        user_id: int,
        attempt_id: UUID,
    ):
        logger.info("Fetching attempt_id=%s", attempt_id)

        return self.repository.get_attempt_by_id(
            attempt_id=attempt_id,
            user_id=user_id,
        )

    # =========================
    # Complete Scenario
    # =========================

    def complete_scenario(
        self,
        user_id: int,
        attempt_id: UUID,
        duration_seconds: int,
        end_reason: str,
        analysis_result: dict,
        is_best_attempt: bool,
    ):
        attempt = self.repository.get_attempt_by_id(
            attempt_id=attempt_id,
            user_id=user_id,
        )

        if attempt is None:
            logger.warning("Attempt not found for user_id=%s", user_id)
            return None

        if attempt.status != self.IN_PROGRESS:
            logger.warning("Attempt is not in progress: %s", attempt_id)
            return None

        if duration_seconds < 15:
            logger.warning("Recording is too short for analysis")
            return None

        if duration_seconds > 300:
            logger.warning("Recording exceeds maximum duration")
            return None

        if analysis_result is None:
            logger.warning("Analysis result is missing")
            return None

        completed_attempt = self.repository.complete_attempt(
            attempt_id=attempt_id,
            duration_seconds=duration_seconds,
            end_reason=end_reason,
            analysis_result=analysis_result,
            status="completed",
        )

        if completed_attempt is None:
            return None

        progress = self.repository.get_user_progress(
            user_id=user_id,
            scenario_id=attempt.scenario_id,
        )

        if progress is None:
            best_attempt_id = attempt_id
        elif is_best_attempt:
            best_attempt_id = attempt_id
        else:
            best_attempt_id = progress.best_attempt_id

        self.repository.create_or_update_progress(
            user_id=user_id,
            scenario_id=attempt.scenario_id,
            latest_attempt_id=attempt_id,
            best_attempt_id=best_attempt_id,
        )

        logger.info("Scenario completed: attempt_id=%s", attempt_id)

        return completed_attempt