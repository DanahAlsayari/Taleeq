from datetime import datetime

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from application_layer.authentication_managment.auth import (
    get_current_user,
)
from application_layer.training_management.real_life_challenge_service import (
    ensure_current_challenge,
    get_challenge_history,
    get_current_challenge,
    next_challenge,
    save_challenge_reflection,
    set_challenge_completion,
)
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User


router = APIRouter(
    prefix="/real-life-challenges",
    tags=["Real-life Challenges"],
)


class ChallengeAttemptOut(BaseModel):
    id: int
    challenge_id: int
    title: str
    instructions: str
    is_current: bool
    is_completed: bool
    assigned_at: datetime
    completed_at: datetime | None
    reflection: str | None
    reflection_updated_at: datetime | None


class ChallengeHistoryOut(BaseModel):
    items: list[ChallengeAttemptOut]
    has_more: bool


class CompletionInput(BaseModel):
    is_completed: bool = Field(strict=True)


class ReflectionInput(BaseModel):
    reflection: str = Field(strict=True, max_length=2000)


@router.get(
    "/current",
    response_model=ChallengeAttemptOut | None,
)
def read_current_challenge(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_current_challenge(
        db=db,
        user_id=current_user.id,
    )


@router.post(
    "/current",
    response_model=ChallengeAttemptOut,
)
def assign_current_challenge(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return ensure_current_challenge(
        db=db,
        user_id=current_user.id,
    )


@router.get(
    "/history",
    response_model=ChallengeHistoryOut,
)
def read_challenge_history(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_challenge_history(
        db=db,
        user_id=current_user.id,
        limit=limit,
        offset=offset,
    )


@router.patch(
    "/{attempt_id}/completion",
    response_model=ChallengeAttemptOut,
)
def update_challenge_completion(
    attempt_id: int,
    body: CompletionInput,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return set_challenge_completion(
        db=db,
        user_id=current_user.id,
        attempt_id=attempt_id,
        completed=body.is_completed,
    )


@router.put(
    "/{attempt_id}/reflection",
    response_model=ChallengeAttemptOut,
)
def update_challenge_reflection(
    attempt_id: int,
    body: ReflectionInput,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return save_challenge_reflection(
        db=db,
        user_id=current_user.id,
        attempt_id=attempt_id,
        reflection=body.reflection,
    )


@router.post(
    "/{attempt_id}/next",
    response_model=ChallengeAttemptOut,
)
def assign_next_challenge(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return next_challenge(
        db=db,
        user_id=current_user.id,
        attempt_id=attempt_id,
    )