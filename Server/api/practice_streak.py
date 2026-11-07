from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from application_layer.authentication_managment.auth import (
    get_current_user,
)
from application_layer.training_management.practice_streak_service import (
    get_practice_streak,
)
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User


router = APIRouter(
    prefix="/practice-streak",
    tags=["Practice Streak"],
)


@router.get("")
def read_practice_streak(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_practice_streak(db=db, user_id=current_user.id)