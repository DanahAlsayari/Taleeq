import logging
from uuid import UUID

from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException
from openai import APIError, APIConnectionError, RateLimitError
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from application_layer.authentication_managment.auth import (
    get_current_user,
)
from application_layer.training_management.scenario_realtime_service import (
    ScenarioRealtimeService,
)


logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/scenarios",
    tags=["Scenarios"],
)


@router.post("/attempts/{attempt_id}/realtime-session")
def create_realtime_session(
    attempt_id: UUID,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    service = ScenarioRealtimeService(db)

    try:
        result = service.create_session_token(
            user_id=current_user.id,
            attempt_id=attempt_id,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=500,
            detail=str(error),
        )

    except (APIConnectionError, RateLimitError, APIError):
        raise HTTPException(
            status_code=502,
            detail="Unable to initialize the Realtime session.",
        )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Attempt, scenario, or difficulty not found.",
        )

    return result

class CompleteRealtimeScenarioRequest(BaseModel):
    duration_seconds: int = Field(ge=15, le=300)
    end_reason: str = Field(default="user_ended", min_length=1, max_length=50)
    analysis_result: dict


@router.post("/attempts/{attempt_id}/complete-realtime")
def complete_realtime_scenario(
    attempt_id: UUID,
    payload: CompleteRealtimeScenarioRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    service = ScenarioRealtimeService(db)

    try:
        result = service.complete_scenario(
            user_id=current_user.id,
            attempt_id=attempt_id,
            duration_seconds=payload.duration_seconds,
            end_reason=payload.end_reason,
            analysis_result=payload.analysis_result,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Scenario attempt not found or is no longer in progress.",
        )

    return result

