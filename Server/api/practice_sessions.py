from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, selectinload

from application_layer.authentication_managment.auth import (
    get_current_user,
)
from application_layer.training_management.practice_session_service import (
    get_or_create_today_session,
    serialize_session,
    start_or_resume_session,
    get_session_exercise,
    PracticeSessionNotFoundError,
    PracticeSessionConflictError,
    get_today_session_state,
)
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.practice_session import (
    PracticeSession,
)
from data_and_integration_layer.database.models.user import User


router = APIRouter(
    prefix="/practice-sessions",
    tags=["Practice Sessions"],
)


class PrepareSessionRequest(BaseModel):
    additional_session: bool = Field(default=False, strict=True)


@router.post("/today")
def prepare_today_session(
    request: PrepareSessionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return get_or_create_today_session(
            db=db,
            user_id=current_user.id,
            additional_session=request.additional_session,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

@router.get("/today")
def read_today_session_state(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_today_session_state(
        db=db,
        user_id=current_user.id,
    )

@router.get("/{session_id}")
def read_session(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = (
        db.query(PracticeSession)
        .options(selectinload(PracticeSession.exercises))
        .filter(
            PracticeSession.id == session_id,
            PracticeSession.user_id == current_user.id,
        )
        .one_or_none()
    )

    if session is None:
        raise HTTPException(
            status_code=404,
            detail="Practice session not found.",
        )

    return serialize_session(session)

@router.post("/{session_id}/start")
def start_session(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return start_or_resume_session(
            db=db,
            user_id=current_user.id,
            session_id=session_id,
        )
    except PracticeSessionNotFoundError as error:
        raise HTTPException(
            status_code=404,
            detail=str(error),
        ) from error
    except PracticeSessionConflictError as error:
        raise HTTPException(
            status_code=409,
            detail=str(error),
        ) from error

@router.get("/{session_id}/exercises/{session_exercise_id}")
def read_session_exercise(
    session_id: int,
    session_exercise_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return get_session_exercise(
            db=db,
            user_id=current_user.id,
            session_id=session_id,
            session_exercise_id=session_exercise_id,
        )
    except PracticeSessionNotFoundError as error:
        raise HTTPException(
            status_code=404,
            detail=str(error),
        ) from error
    except PracticeSessionConflictError as error:
        raise HTTPException(
            status_code=409,
            detail=str(error),
        ) from error