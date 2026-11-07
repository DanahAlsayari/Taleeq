from datetime import datetime
from uuid import UUID

from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.scenario import Scenario
from data_and_integration_layer.database.models.scenario_difficulty import (
    ScenarioDifficulty,
)
from data_and_integration_layer.database.models.scenario_attempt import (
    ScenarioAttempt,
)
from data_and_integration_layer.database.models.scenario_user_progress import (
    ScenarioUserProgress,
)


class ScenarioRepository:
    def __init__(self, db: Session):
        self.db = db

    # =========================
    # Scenarios
    # =========================

    def get_active_scenarios(self):
        return (
            self.db.query(Scenario)
            .filter(Scenario.is_active.is_(True))
            .order_by(Scenario.name)
            .all()
        )

    def get_scenario_by_id(self, scenario_id: UUID):
        return (
            self.db.query(Scenario)
            .filter(Scenario.id == scenario_id)
            .first()
        )

    # =========================
    # Scenario Difficulties
    # =========================

    def get_active_difficulties(self, scenario_id: UUID):
        return (
            self.db.query(ScenarioDifficulty)
            .filter(
                ScenarioDifficulty.scenario_id == scenario_id,
                ScenarioDifficulty.is_active.is_(True),
            )
            .order_by(ScenarioDifficulty.difficulty)
            .all()
        )

    def get_difficulty_by_id(
        self,
        scenario_id: UUID,
        difficulty_id: UUID,
    ):
        return (
            self.db.query(ScenarioDifficulty)
            .filter(
                ScenarioDifficulty.id == difficulty_id,
                ScenarioDifficulty.scenario_id == scenario_id,
                ScenarioDifficulty.is_active.is_(True),
            )
            .first()
        )

    # =========================
    # Scenario Attempts
    # =========================

    def create_attempt(
        self,
        user_id: int,
        scenario_id: UUID,
        scenario_difficulty_id: UUID,
        status: str,
    ):
        attempt = ScenarioAttempt(
            user_id=user_id,
            scenario_id=scenario_id,
            scenario_difficulty_id=scenario_difficulty_id,
            status=status,
        )

        try:
            self.db.add(attempt)
            self.db.commit()
            self.db.refresh(attempt)
            return attempt

        except Exception:
            self.db.rollback()
            raise

    def get_attempt_by_id(
        self,
        attempt_id: UUID,
        user_id: int = None,
    ):
        query = self.db.query(ScenarioAttempt).filter(
            ScenarioAttempt.id == attempt_id
        )

        if user_id is not None:
            query = query.filter(ScenarioAttempt.user_id == user_id)

        return query.first()

    def complete_attempt_and_update_progress(
        self,
        user_id: int,
        scenario_id: UUID,
        attempt_id: UUID,
        duration_seconds: int,
        end_reason: str,
        analysis_result: dict,
        best_attempt_id: UUID,
        status: str,
    ):
        attempt = self.get_attempt_by_id(
            attempt_id=attempt_id,
            user_id=user_id,
        )
        if attempt is None:
            return None

        try:
            attempt.status = status
            attempt.ended_at = datetime.utcnow()
            attempt.duration_seconds = duration_seconds
            attempt.end_reason = end_reason
            attempt.analysis_result = analysis_result

            progress = self.get_user_progress(user_id, scenario_id)
            if progress is None:
                progress = ScenarioUserProgress(
                    user_id=user_id,
                    scenario_id=scenario_id,
                    latest_attempt_id=attempt_id,
                    best_attempt_id=best_attempt_id,
                )
                self.db.add(progress)
            else:
                progress.latest_attempt_id = attempt_id
                progress.best_attempt_id = best_attempt_id
                progress.updated_at = datetime.utcnow()

            # Both records are committed atomically.
            self.db.commit()
            self.db.refresh(attempt)
            self.db.refresh(progress)
            return attempt

        except Exception:
            self.db.rollback()
            raise

    def complete_attempt(
        self,
        attempt_id: UUID,
        duration_seconds: int,
        end_reason: str,
        analysis_result: dict,
        status: str,
    ):
        attempt = self.get_attempt_by_id(attempt_id)

        if attempt is None:
            return None

        try:
            attempt.status = status
            attempt.ended_at = datetime.utcnow()
            attempt.duration_seconds = duration_seconds
            attempt.end_reason = end_reason
            attempt.analysis_result = analysis_result

            self.db.commit()
            self.db.refresh(attempt)

            return attempt

        except Exception:
            self.db.rollback()
            raise

    # =========================
    # User Progress
    # =========================

    def get_user_progress(
        self,
        user_id: int,
        scenario_id: UUID,
    ):
        return (
            self.db.query(ScenarioUserProgress)
            .filter(
                ScenarioUserProgress.user_id == user_id,
                ScenarioUserProgress.scenario_id == scenario_id,
            )
            .first()
        )

    def create_or_update_progress(
        self,
        user_id: int,
        scenario_id: UUID,
        latest_attempt_id: UUID,
        best_attempt_id: UUID,
    ):
        progress = self.get_user_progress(user_id, scenario_id)

        try:
            if progress is None:
                progress = ScenarioUserProgress(
                    user_id=user_id,
                    scenario_id=scenario_id,
                    latest_attempt_id=latest_attempt_id,
                    best_attempt_id=best_attempt_id,
                )
                self.db.add(progress)

            else:
                progress.latest_attempt_id = latest_attempt_id
                progress.best_attempt_id = best_attempt_id
                progress.updated_at = datetime.utcnow()

            self.db.commit()
            self.db.refresh(progress)

            return progress

        except Exception:
            self.db.rollback()
            raise



    # =========================
    # Scenario attempts by user
    # =========================

    def get_attempts_by_user(self, user_id: int):
        return (
            self.db.query(ScenarioAttempt)
            .filter(ScenarioAttempt.user_id == user_id)
            .order_by(ScenarioAttempt.started_at.desc())
            .all()
        )
