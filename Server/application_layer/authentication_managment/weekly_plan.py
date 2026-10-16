from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, selectinload

from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User

from . import auth
from .weekly_plan_schemas import (
    PracticeCompletionInput,
    PracticeSessionOut,
    WeeklyPlanInput,
    WeeklyPlanOut,
)
from data_and_integration_layer.database.models.weekly_plan import (
    PlannedPracticeSession,
    WeeklyPlan,
)

router = APIRouter(
    prefix="/weekly-plan",
    tags=["Weekly plan"],
)

RIYADH_TIMEZONE = timezone(timedelta(hours=3))


def local_today() -> date:
    return datetime.now(RIYADH_TIMEZONE).date()


def get_week_start(day: date) -> date:
    # Python: Monday = 0, Sunday = 6.
    # Our calendar week starts on Sunday.
    days_since_sunday = (day.weekday() + 1) % 7
    return day - timedelta(days=days_since_sunday)


@router.get("", response_model=WeeklyPlanOut | None)
def get_weekly_plan(
    week_start: date | None = None,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    selected_week = week_start or get_week_start(local_today())

    if selected_week != get_week_start(selected_week):
        raise HTTPException(
            status_code=422,
            detail="يجب أن يبدأ الأسبوع يوم الأحد.",
        )

    plan = (
        db.query(WeeklyPlan)
        .options(selectinload(WeeklyPlan.sessions))
        .filter(
            WeeklyPlan.user_id == current_user.id,
            WeeklyPlan.week_start == selected_week,
        )
        .first()
    )

    if plan is not None:
        plan.sessions.sort(
            key=lambda session: session.practice_date,
        )

    return plan

@router.put("", response_model=WeeklyPlanOut)
def save_weekly_plan(
    request: WeeklyPlanInput,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    today = local_today()
    current_week = get_week_start(today)

    if request.week_start != current_week:
        raise HTTPException(
            status_code=422,
            detail="يمكن تعديل خطة الأسبوع الحالي فقط.",
        )

    # Serialize schedule changes for this user.
    db.query(User).filter(
        User.id == current_user.id,
    ).with_for_update().one()

    plan = (
        db.query(WeeklyPlan)
        .filter(
            WeeklyPlan.user_id == current_user.id,
            WeeklyPlan.week_start == current_week,
        )
        .first()
    )

    requested_sessions = {
        session.practice_date: session.duration_minutes
        for session in request.sessions
    }

    if plan is None:
        plan = WeeklyPlan(
            user_id=current_user.id,
            week_start=current_week,
        )
        db.add(plan)
        db.flush()

    existing_sessions = {
        session.practice_date: session
        for session in plan.sessions
    }

    # Keep completed sessions and past dates unchanged.
    for practice_date, session in existing_sessions.items():
        protected = (
            session.is_completed
            or practice_date < today
        )

        if protected:
            requested_duration = requested_sessions.get(
                practice_date,
            )

            if requested_duration != session.duration_minutes:
                raise HTTPException(
                    status_code=409,
                    detail=(
                        "لا يمكن حذف الجلسات المكتملة أو الماضية "
                        "أو تعديل مدتها."
                    ),
                )

    # Prevent adding new sessions to past dates.
    for practice_date in requested_sessions:
        if (
            practice_date < today
            and practice_date not in existing_sessions
        ):
            raise HTTPException(
                status_code=422,
                detail="لا يمكن إضافة جلسة إلى يوم مضى.",
            )

    # Remove uncompleted sessions omitted from the new schedule.
    for practice_date, session in existing_sessions.items():
        if practice_date not in requested_sessions:
            db.delete(session)

    # Update existing sessions or add new ones.
    for practice_date, duration in requested_sessions.items():
        session = existing_sessions.get(practice_date)

        if session is None:
            db.add(
                PlannedPracticeSession(
                    plan_id=plan.id,
                    practice_date=practice_date,
                    duration_minutes=duration,
                )
            )
        elif (
            not session.is_completed
            and practice_date >= today
        ):
            session.duration_minutes = duration

    db.commit()
    db.refresh(plan)

    plan.sessions.sort(
        key=lambda session: session.practice_date,
    )

    return plan

@router.patch(
    "/sessions/{session_id}/completion",
    response_model=PracticeSessionOut,
)
def update_practice_completion(
    session_id: int,
    request: PracticeCompletionInput,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    # Use the same lock as schedule editing.
    db.query(User).filter(
        User.id == current_user.id,
    ).with_for_update().one()

    session = (
        db.query(PlannedPracticeSession)
        .join(
            WeeklyPlan,
            PlannedPracticeSession.plan_id == WeeklyPlan.id,
        )
        .filter(
            PlannedPracticeSession.id == session_id,
            WeeklyPlan.user_id == current_user.id,
        )
        .first()
    )

    if session is None:
        raise HTTPException(
            status_code=404,
            detail="الجلسة غير موجودة.",
        )

    today = local_today()

    if session.plan.week_start != get_week_start(today):
        raise HTTPException(
            status_code=409,
            detail="يمكن تحديث الإنجاز للأسبوع الحالي فقط.",
        )

    if request.is_completed and not session.is_completed:
        session.is_completed = True
        session.completed_at = datetime.now(timezone.utc)

    elif not request.is_completed and session.is_completed:
        session.is_completed = False
        session.completed_at = None

    db.commit()
    db.refresh(session)

    return session