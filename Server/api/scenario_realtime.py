import logging
from uuid import UUID

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