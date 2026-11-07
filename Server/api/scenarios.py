import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from application_layer.authentication_managment.auth import (
    get_current_user,
)
from application_layer.training_management.scenario_service import (
    ScenarioService,
)


logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/scenarios",
    tags=["Scenarios"],
)


# =========================
# Get Active Scenarios
# =========================

@router.get("")
def get_active_scenarios(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    logger.info(
        "[ScenarioAPI] Fetching scenarios for user_id=%s",
        current_user.id,
    )

    service = ScenarioService(db)

    return service.get_active_scenarios()

# =========================
# Get all User Attempt
# =========================
@router.get("/attempts")
def get_user_scenario_attempts(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    service = ScenarioService(db)

    return service.get_user_scenario_attempts(
        user_id=current_user.id,
    )



# =========================
# Get Scenario Details
# =========================

@router.get("/{scenario_id}")
def get_scenario_details(
    scenario_id: UUID,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    logger.info(
        "[ScenarioAPI] Fetching scenario_id=%s",
        scenario_id,
    )

    service = ScenarioService(db)

    result = service.get_scenario_details(scenario_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Scenario not found",
        )

    return result



# =========================
# Start Scenario
# =========================

@router.post("/{scenario_id}/start")
def start_scenario(
    scenario_id: UUID,
    difficulty_id: UUID,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    logger.info(
        "[ScenarioAPI] Starting scenario_id=%s for user_id=%s",
        scenario_id,
        current_user.id,
    )

    service = ScenarioService(db)

    attempt = service.start_scenario(
        user_id=current_user.id,
        scenario_id=scenario_id,
        difficulty_id=difficulty_id,
    )

    if attempt is None:
        raise HTTPException(
            status_code=404,
            detail="Scenario or difficulty not found",
        )

    return attempt


# =========================
# Get User Attempt
# =========================

@router.get("/attempts/{attempt_id}")
def get_user_attempt(
    attempt_id: UUID,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    logger.info(
        "[ScenarioAPI] Fetching attempt_id=%s for user_id=%s",
        attempt_id,
        current_user.id,
    )

    service = ScenarioService(db)

    attempt = service.get_user_attempt(
        user_id=current_user.id,
        attempt_id=attempt_id,
    )

    if attempt is None:
        raise HTTPException(
            status_code=404,
            detail="Scenario attempt not found",
        )

    return attempt



