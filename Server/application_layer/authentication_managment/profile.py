from datetime import time

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from application_layer.authentication_managment import auth, profile_schemas
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.reminder_setting import ReminderSetting
from data_and_integration_layer.database.models.training_goal import TrainingGoal
from data_and_integration_layer.database.models.user import User


router = APIRouter(prefix="/profile", tags=["Profile"])


@router.get("", response_model=profile_schemas.ProfileOut)
def get_profile(
    current_user: User = Depends(auth.get_current_user),
):
    return current_user


@router.get(
    "/goals",
    response_model=list[profile_schemas.TrainingGoalOut],
)
def get_goals(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(TrainingGoal)
        .filter(TrainingGoal.user_id == current_user.id)
        .all()
    )


@router.post(
    "/goals",
    response_model=profile_schemas.TrainingGoalOut,
)
def add_goal(
    data: profile_schemas.TrainingGoalCreate,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    goal_text = data.goal.strip()

    if not goal_text:
        raise HTTPException(
            status_code=400,
            detail="Goal cannot be empty",
        )

    goal = TrainingGoal(
        user_id=current_user.id,
        goal=goal_text,
    )

    db.add(goal)
    db.commit()
    db.refresh(goal)

    return goal


@router.put(
    "/goals/{goal_id}",
    response_model=profile_schemas.TrainingGoalOut,
)
def update_goal(
    goal_id: int,
    data: profile_schemas.TrainingGoalUpdate,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    goal = (
        db.query(TrainingGoal)
        .filter(
            TrainingGoal.id == goal_id,
            TrainingGoal.user_id == current_user.id,
        )
        .first()
    )

    if not goal:
        raise HTTPException(
            status_code=404,
            detail="Goal not found",
        )

    goal_text = data.goal.strip()

    if not goal_text:
        raise HTTPException(
            status_code=400,
            detail="Goal cannot be empty",
        )

    goal.goal = goal_text

    db.commit()
    db.refresh(goal)

    return goal


@router.delete("/goals/{goal_id}")
def delete_goal(
    goal_id: int,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    goal = (
        db.query(TrainingGoal)
        .filter(
            TrainingGoal.id == goal_id,
            TrainingGoal.user_id == current_user.id,
        )
        .first()
    )

    if not goal:
        raise HTTPException(
            status_code=404,
            detail="Goal not found",
        )

    db.delete(goal)
    db.commit()

    return {
        "message": "Goal deleted successfully",
    }


@router.get(
    "/reminder",
    response_model=profile_schemas.ReminderSettingOut,
)
def get_reminder(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    reminder = (
        db.query(ReminderSetting)
        .filter(ReminderSetting.user_id == current_user.id)
        .first()
    )

    if reminder:
        return reminder

    reminder = ReminderSetting(
        user_id=current_user.id,
        enabled=True,
        reminder_time=time(hour=18, minute=0),
    )

    db.add(reminder)
    db.commit()
    db.refresh(reminder)

    return reminder


@router.put(
    "/reminder",
    response_model=profile_schemas.ReminderSettingOut,
)
def update_reminder(
    data: profile_schemas.ReminderSettingUpdate,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    reminder = (
        db.query(ReminderSetting)
        .filter(ReminderSetting.user_id == current_user.id)
        .first()
    )

    if not reminder:
        reminder = ReminderSetting(
            user_id=current_user.id,
            enabled=data.enabled,
            reminder_time=data.reminder_time,
        )
        db.add(reminder)
    else:
        reminder.enabled = data.enabled
        reminder.reminder_time = data.reminder_time

    db.commit()
    db.refresh(reminder)

    return reminder