import os
import uuid
import requests
from datetime import time, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session

from application_layer.authentication_managment import auth, profile_schemas
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.reminder_setting import ReminderSetting
from data_and_integration_layer.database.models.training_goal import TrainingGoal
from data_and_integration_layer.database.models.user import User

from . import schemas
from . import email_change_service
from application_layer.authentication_managment.account_deletion_service import (
    delete_user_account,
)

router = APIRouter(prefix="/profile", tags=["Profile"])


def get_profile_picture_url(image_path: str | None) -> str | None:
    if not image_path:
        return None

    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not supabase_key:
        return None

    url = (
        f"{supabase_url.rstrip('/')}/storage/v1/object/sign/"
        f"profile-pictures/{image_path}"
    )

    headers = {
        "apikey": supabase_key,
        "Content-Type": "application/json",
    }

    if not supabase_key.startswith("sb_secret_"):
        headers["Authorization"] = f"Bearer {supabase_key}"

    try:
        response = requests.post(
            url,
            headers=headers,
            json={"expiresIn": 3600},
            timeout=15,
        )
        response.raise_for_status()

        signed_url = response.json().get("signedURL")

        if not signed_url:
            return None
        if signed_url.startswith("http"):
            return signed_url
        return (
            f"{supabase_url.rstrip('/')}/storage/v1"
            f"{signed_url if signed_url.startswith('/') else '/' + signed_url}"
        )

    except (requests.RequestException, ValueError):
        return None


@router.get("", response_model=profile_schemas.ProfileOut)
def get_profile(
    current_user: User = Depends(auth.get_current_user),
):
    return {
        "id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "profile_picture_url": get_profile_picture_url(
            current_user.profile_picture_path
        ),
    }


@router.patch(
    "/name",
    response_model=profile_schemas.ProfileOut,
)
def update_profile_name(
    data: profile_schemas.ProfileNameUpdate,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    current_user.name = data.name
    db.commit()
    db.refresh(current_user)

    return current_user


@router.get(
    "/goals",
    response_model=list[profile_schemas.TrainingGoalOut],
)
def get_goals(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(TrainingGoal).filter(TrainingGoal.user_id == current_user.id).all()


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
    current_user.training_goals_changed_at = datetime.now(timezone.utc)
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
    goal_changed = False

    # Update goal text only if provided
    if data.goal is not None:
        goal_text = data.goal.strip()

        if not goal_text:
            raise HTTPException(
                status_code=400,
                detail="Goal cannot be empty",
            )

        if goal.goal != goal_text:
            goal.goal = goal_text
            goal_changed = True

    # Update completion status only if provided
    if data.is_completed is not None:
        if goal.is_completed != data.is_completed:
            goal.is_completed = data.is_completed
            goal_changed = True

    if goal_changed:
        current_user.training_goals_changed_at = datetime.now(timezone.utc)
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
    current_user.training_goals_changed_at = datetime.now(timezone.utc)
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


def delete_profile_picture_from_storage(image_path: str) -> bool:
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not supabase_key:
        return False

    delete_url = (
        f"{supabase_url.rstrip('/')}/storage/v1/object/"
        f"profile-pictures/{image_path}"
    )

    headers = {
        "apikey": supabase_key,
    }

    if not supabase_key.startswith("sb_secret_"):
        headers["Authorization"] = f"Bearer {supabase_key}"

    try:
        response = requests.delete(
            delete_url,
            headers=headers,
            timeout=15,
        )

        if response.status_code not in (200, 204):
            print(
                "SUPABASE DELETE ERROR:",
                response.status_code,
                response.text,
            )
            return False

        return True

    except requests.RequestException as e:
        print("SUPABASE DELETE ERROR:", str(e))
        return False


@router.post("/picture")
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    allowed_types = {
        "image/jpeg",
        "image/png",
        "image/webp",
    }

    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail="Only JPEG, PNG, and WebP images are allowed",
        )

    image_bytes = await file.read(2 * 1024 * 1024 + 1)

    if len(image_bytes) > 2 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Profile picture must not exceed 2 MB",
        )

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="Image file cannot be empty",
        )

    def is_valid_image(data: bytes, content_type: str) -> bool:
        if content_type == "image/jpeg":
            return data.startswith(b"\xff\xd8\xff") and data.endswith(b"\xff\xd9")

        if content_type == "image/png":
            return data.startswith(b"\x89PNG\r\n\x1a\n")

        if content_type == "image/webp":
            return (
                len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP"
            )

        return False

    if not is_valid_image(image_bytes, file.content_type):
        raise HTTPException(
            status_code=400,
            detail="Invalid image file",
        )

    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not supabase_key:
        raise HTTPException(
            status_code=500,
            detail="Supabase Storage is not configured",
        )

    extensions = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
    }

    extension = extensions[file.content_type]

    image_name = f"{uuid.uuid4().hex}.{extension}"
    image_path = f"users/{current_user.id}/{image_name}"

    upload_url = (
        f"{supabase_url.rstrip('/')}/storage/v1/object/"
        f"profile-pictures/{image_path}"
    )

    headers = {
        "apikey": supabase_key,
        "Content-Type": file.content_type,
        "x-upsert": "false",
    }

    if not supabase_key.startswith("sb_secret_"):
        headers["Authorization"] = f"Bearer {supabase_key}"

    try:
        response = requests.post(
            upload_url,
            headers=headers,
            data=image_bytes,
            timeout=30,
        )
    except requests.RequestException:
        raise HTTPException(
            status_code=502,
            detail="Could not connect to image storage",
        )

    if response.status_code not in (200, 201):
        print(
            "SUPABASE UPLOAD ERROR:",
            response.status_code,
            response.text,
        )
        raise HTTPException(
            status_code=502,
            detail="Failed to upload profile picture",
        )

    old_image_path = current_user.profile_picture_path
    current_user.profile_picture_path = image_path

    try:
        db.commit()
        db.refresh(current_user)
    except Exception:
        db.rollback()
        delete_profile_picture_from_storage(image_path)

        raise HTTPException(
            status_code=500,
            detail="Failed to save profile picture",
        )

    if old_image_path and old_image_path != image_path:
        delete_profile_picture_from_storage(old_image_path)

    return {
        "message": "Profile picture uploaded successfully",
        "profile_picture_path": current_user.profile_picture_path,
    }


@router.delete("/picture")
def delete_profile_picture(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    old_image_path = current_user.profile_picture_path

    if not old_image_path:
        return {"message": "No profile picture to delete"}

    if not delete_profile_picture_from_storage(old_image_path):
        raise HTTPException(
            status_code=502,
            detail="Failed to delete profile picture from storage",
        )

    current_user.profile_picture_path = None

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Failed to update profile picture",
        )

    return {"message": "Profile picture deleted successfully"}


@router.post(
    "/email/request",
    response_model=schemas.EmailChangeOTPResponse,
)
def request_profile_email_change(
    data: schemas.RequestEmailChange,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    return email_change_service.request_email_change(
        data,
        current_user,
        db,
    )


@router.post(
    "/email/resend",
    response_model=schemas.EmailChangeOTPResponse,
)
def resend_profile_email_change(
    data: schemas.ResendEmailChangeOTP,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    return email_change_service.resend_email_change(
        data,
        current_user,
        db,
    )


@router.post("/email/verify")
def verify_profile_email_change(
    data: schemas.VerifyEmailChangeOTP,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    return email_change_service.verify_email_change(
        data,
        current_user,
        db,
    )


@router.delete("")
def delete_account(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    try:
        profile_picture_path = delete_user_account(db, current_user.id)
        db.commit()

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Failed to delete account",
        )

    if profile_picture_path:
        try:
            delete_profile_picture_from_storage(profile_picture_path)
        except Exception as e:
            print(f"Failed to delete profile picture after account deletion: {e}")

    return {"message": "Account deleted successfully"}
