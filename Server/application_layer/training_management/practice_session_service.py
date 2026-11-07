import logging
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.user import User
from data_and_integration_layer.database.models.practice_session import (
    PracticeSession,
    PracticeSessionExercise,
)
from application_layer.training_management.exercise_selection_service import (
    preview_personalized_session,
    get_schedule_for_date,)
from data_and_integration_layer.database.models.technique import Technique
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session, selectinload
from application_layer.training_management.session_result_service import (
    ensure_session_result,
)
from application_layer.training_management.technique_recommendation_service import (
    TechniqueRecommendationService,
)
from data_and_integration_layer.database.models.weekly_plan import (
    PlannedPracticeSession,
    WeeklyPlan,
)

logger = logging.getLogger(__name__)

def serialize_session(session: PracticeSession) -> dict:
    exercises = []

    for item in session.exercises:
        exercises.append(
            {
                **item.exercise_snapshot,
                "session_exercise_id": item.id,
                "exercise_id": str(item.exercise_id),
                "position": item.position,
                "technique_id": item.technique_id,
                "status": item.status,
                "target_recording_seconds": (item.target_recording_seconds),
            }
        )

    return {
        "session_id": session.id,
        "assessment_id": session.assessment_id,
        "practice_date": session.practice_date.isoformat(),
        "sequence_number": session.sequence_number,
        "additional_session": session.additional_session,
        "target_duration_minutes": session.target_duration_minutes,
        "status": session.status,
        "exercise_count": len(exercises),
        "total_target_recording_seconds": sum(
            item["target_recording_seconds"] for item in exercises
        ),
        "exercises": exercises,
    }


def get_or_create_today_session(
    db: Session,
    user_id: int,
    additional_session: bool = False,
) -> dict:
    """Save or reopen a session. Owns commit/rollback for this operation."""

    from datetime import datetime, timedelta, timezone

    today = datetime.now(timezone(timedelta(hours=3))).date()

    try:
        # Serialize session creation for the same user.
        user = db.query(User).filter(User.id == user_id).with_for_update().one_or_none()

        if user is None:
            raise ValueError("User not found.")

        # Apply the same priority used by the homepage.
        homepage = get_today_session_state(db=db, user_id=user_id)

        if homepage["session"] is not None:
            response = homepage["session"]
            db.commit()
            return response

        last_sequence = (
            db.query(func.max(PracticeSession.sequence_number))
            .filter(PracticeSession.user_id == user_id)
            .scalar()
        )

        sequence_number = (last_sequence or 0) + 1
        # The saved schedule determines whether this is optional practice.
        schedule = get_schedule_for_date(
            db=db,
            user_id=user_id,
            practice_date=today,
        )
        additional_session = schedule["duration_minutes"] is None
        preview = preview_personalized_session(
            db=db,
            user_id=user_id,
            session_number=sequence_number,
            additional_session=additional_session,
        )
        technique_service = TechniqueRecommendationService(db)

        active_goals, techniques = technique_service.get_recommendation_inputs(user_id)

        categories = technique_service.classify_active_goals(active_goals)
        print("GOAL CATEGORIES:", categories)

        scores = technique_service.calculate_goal_scores(categories, techniques)
        completed_session_counts = (
            technique_service.practice_session_repository.get_completed_session_counts(
                user_id
            )
        )
        initial_complete = technique_service.is_initial_practice_complete(
            scores,
            completed_session_counts,
        )
        completed_exercises = (
            technique_service.practice_session_repository.get_completed_exercises(
                user_id
            )
        )

        completion_session_id = technique_service.get_initial_practice_completion_time(
            scores,
            completed_exercises,
        )

        completed_after_initial = (
            technique_service.count_sessions_after_initial_practice(
                user_id,
                completion_session_id,
            )
        )

        sessions_since_initial_phase = completed_after_initial + 1
        candidates = technique_service.get_session_technique_candidates(
            techniques=techniques,
            scores=scores,
            completed_session_counts=completed_session_counts,
            sessions_since_initial_phase=sessions_since_initial_phase,
        )
        selected_techniques = technique_service.select_session_techniques(
            candidates=candidates,
            exercise_count=len(preview["exercises"]),
        )

        session = PracticeSession(
            user_id=user_id,
            assessment_id=preview["assessment_id"],
            planned_practice_session_id=preview["planned_practice_session_id"],
            practice_date=today,
            sequence_number=sequence_number,
            additional_session=additional_session,
            target_duration_minutes=preview["target_duration_minutes"],
            status="ready",
        )

        session.exercises = [
            PracticeSessionExercise(
                exercise_id=UUID(item["exercise_id"]),
                position=item["position"],
                selection_role=item["selection_role"],
                exercise_snapshot=dict(item),
                target_recording_seconds=item["target_recording_seconds"],
                status="pending",
                technique_id=selected_techniques[index].id,
            )
            for index, item in enumerate(preview["exercises"])
        ]

        db.add(session)
        db.flush()

        response = serialize_session(session)
        db.commit()

        return response

    except Exception:
        db.rollback()
        raise


class PracticeSessionNotFoundError(LookupError):
    pass


class PracticeSessionConflictError(ValueError):
    pass


def _get_owned_session(
    db: Session,
    user_id: int,
    session_id: int,
) -> PracticeSession:
    session = (
        db.query(PracticeSession)
        .filter(
            PracticeSession.id == session_id,
            PracticeSession.user_id == user_id,
        )
        .one_or_none()
    )

    if session is None:
        raise PracticeSessionNotFoundError("Practice session not found.")

    return session


def start_or_resume_session(
    db: Session,
    user_id: int,
    session_id: int,
    session_exercise_id: int | None = None,
) -> dict:
    """Start the session or resume its first unfinished exercise."""

    try:
        # Use the same user lock as session creation.
        user = db.query(User).filter(User.id == user_id).with_for_update().one_or_none()

        if user is None:
            raise PracticeSessionNotFoundError("Practice session not found.")

        session = _get_owned_session(db, user_id, session_id)

        if session.status == "cancelled":
            raise PracticeSessionConflictError("This session has been cancelled.")

        if session_exercise_id is None:
            next_item = next(
                (
                    item
                    for item in sorted(
                        session.exercises,
                        key=lambda item: item.position
                    )
                    if item.status != "completed"
                ),
                None,
            )
        else:
            next_item = next(
                (
                    item
                    for item in session.exercises
                    if item.id == session_exercise_id
                ),
                None,
            )

            if next_item is None:
                raise PracticeSessionNotFoundError(
                    "Session exercise not found."
                )

            if next_item.status == "completed":
                raise PracticeSessionConflictError(
                    "This session exercise is already completed."
                )

        if session.status == "completed":
            response = serialize_session(session)
            response["next_session_exercise_id"] = None
            db.commit()
            return response

        if next_item is None:
            raise PracticeSessionConflictError(
                "This session has no unfinished exercises."
            )

        if session.status == "ready":
            session.status = "in_progress"

        if session.started_at is None:
            session.started_at = datetime.now(timezone.utc)

        for item in session.exercises:
            if item.status == "in_progress" and item.id != next_item.id:
                item.status = "pending"

        next_item.status = "in_progress"

        db.flush()

        response = serialize_session(session)
        response["next_session_exercise_id"] = next_item.id

        db.commit()
        return response

    except Exception:
        db.rollback()
        raise


def get_session_exercise(
    db: Session,
    user_id: int,
    session_id: int,
    session_exercise_id: int,
) -> dict:
    """Read saved exercise data without changing progress."""

    session = _get_owned_session(db, user_id, session_id)

    item = next(
        (
            exercise
            for exercise in session.exercises
            if exercise.id == session_exercise_id
        ),
        None,
    )

    if item is None:
        raise PracticeSessionNotFoundError("Session exercise not found.")

    technique = None

    if item.technique_id is not None:
        technique_model = db.get(Technique, item.technique_id)

        if technique_model is None:
            raise PracticeSessionConflictError("The assigned technique is unavailable.")

        technique = {
            "id": technique_model.id,
            "name_ar": technique_model.name_ar,
            "name_en": technique_model.name_en,
            "category": technique_model.category,
            "description": technique_model.description,
            "steps": technique_model.steps,
            "example": technique_model.example,
            "tips": technique_model.tips,
            "audio_url": technique_model.audio_url,
        }

    # Include the keys expected by the existing exercise flow.
    exercise_data = {
        **item.exercise_snapshot,
        "id": str(item.exercise_id),
        "type": item.exercise_snapshot["exercise_type"],
    }

    return {
        "session_id": session.id,
        "session_exercise_id": item.id,
        "session_status": session.status,
        "status": item.status,
        "position": item.position,
        "exercise_count": len(session.exercises),
        "exercise": exercise_data,
        "technique": technique,
    }


def validate_session_submission(
    db: Session,
    user_id: int,
    session_exercise_id: int,
    exercise_id: UUID,
    technique_id: int | None,
) -> tuple[PracticeSession, PracticeSessionExercise]:
    """Validate a submission without changing progress."""

    session = (
        db.query(PracticeSession)
        .join(
            PracticeSessionExercise,
            PracticeSessionExercise.session_id == PracticeSession.id,
        )
        .options(selectinload(PracticeSession.exercises))
        .filter(
            PracticeSession.user_id == user_id,
            PracticeSessionExercise.id == session_exercise_id,
        )
        .populate_existing()
        .one_or_none()
    )

    if session is None:
        raise PracticeSessionNotFoundError("Session exercise not found.")

    if session.status != "in_progress":
        raise PracticeSessionConflictError(
            "Start or resume the session before submitting."
        )

    item = next(item for item in session.exercises if item.id == session_exercise_id)

    if item.exercise_id != exercise_id:
        raise PracticeSessionConflictError(
            "This exercise does not match the session item."
        )

    if item.status == "completed":
        raise PracticeSessionConflictError(
            "This session exercise is already completed."
        )

    if item.status != "in_progress":
        raise PracticeSessionConflictError(
            "Start this session exercise before submitting."
        )

    if technique_id != item.technique_id:
        raise PracticeSessionConflictError(
            "Use the technique assigned to this session exercise."
        )

    return session, item


def mark_session_exercise_completed(
    db: Session,
    session: PracticeSession,
    item: PracticeSessionExercise,
) -> dict:
    """Update progress inside the attempt's transaction; do not commit."""

    now = datetime.now(timezone.utc)

    item.status = "completed"
    item.completed_at = now

    next_item = next(
        (
            candidate
            for candidate in session.exercises
            if candidate.status != "completed"
        ),
        None,
    )

    if next_item is None:
        session.status = "completed"
        session.completed_at = now

        if session.planned_practice_session_id is not None:
            planned_session = (
                db.query(PlannedPracticeSession)
                .join(
                    WeeklyPlan,
                    PlannedPracticeSession.plan_id == WeeklyPlan.id,
                )
                .filter(
                    PlannedPracticeSession.id
                    == session.planned_practice_session_id,
                    WeeklyPlan.user_id == session.user_id,
                    PlannedPracticeSession.practice_date
                    == session.practice_date,
                )
                .one_or_none()
            )

            if planned_session is None:
                raise PracticeSessionConflictError(
                    "The linked planned practice session is unavailable."
                )

            planned_session.is_completed = True
            planned_session.completed_at = now

    db.flush()

    if next_item is None:
        # Build the session result in the same transaction. A SAVEPOINT keeps
        # a calculation problem from losing the attempt that was just saved;
        # GET /practice-sessions/{id}/result creates the result lazily.
        try:
            with db.begin_nested():
                ensure_session_result(db, session)
        except Exception:
            logger.exception(
                "Could not create the result for session %s",
                session.id,
            )

    return {
        "session_id": session.id,
        "session_exercise_id": item.id,
        "session_status": session.status,
        "completed_exercise_count": sum(
            candidate.status == "completed" for candidate in session.exercises
        ),
        "exercise_count": len(session.exercises),
        "next_session_exercise_id": (next_item.id if next_item is not None else None),
    }


def get_today_session_state(
    db: Session,
    user_id: int,
) -> dict:
    """Choose today's homepage session without creating records."""

    riyadh = timezone(timedelta(hours=3))
    today = datetime.now(riyadh).date()
    day_start = datetime(
        today.year, today.month, today.day, tzinfo=riyadh
    )
    day_end = day_start + timedelta(days=1)

    schedule = get_schedule_for_date(
        db=db,
        user_id=user_id,
        practice_date=today,
    )
    scheduled_today = schedule["duration_minutes"] is not None

    # Today's saved session takes priority over previous sessions.
    today_session = (
        db.query(PracticeSession)
        .options(selectinload(PracticeSession.exercises))
        .filter(
            PracticeSession.user_id == user_id,
            PracticeSession.practice_date == today,
            PracticeSession.status.in_(
                ["ready", "in_progress", "completed"]
            ),
        )
        .order_by(PracticeSession.sequence_number.desc())
        .first()
    )

    # A previous session may have been completed today.
    completed_today = (
        db.query(PracticeSession)
        .options(selectinload(PracticeSession.exercises))
        .filter(
            PracticeSession.user_id == user_id,
            PracticeSession.status == "completed",
            PracticeSession.completed_at >= day_start,
            PracticeSession.completed_at < day_end,
        )
        .order_by(
            PracticeSession.completed_at.desc(),
            PracticeSession.id.desc(),
        )
        .first()
    )

    # Offer the oldest saved unfinished session first.
    previous_session = (
        db.query(PracticeSession)
        .options(selectinload(PracticeSession.exercises))
        .filter(
            PracticeSession.user_id == user_id,
            PracticeSession.practice_date < today,
            PracticeSession.status.in_(["ready", "in_progress"]),
        )
        .order_by(
            PracticeSession.practice_date,
            PracticeSession.sequence_number,
        )
        .first()
    )

    session = today_session

    if session is None and not scheduled_today:
        # After completing a previous session today, stop offering
        # optional practice. Otherwise offer unfinished previous work.
        session = completed_today or previous_session

    next_item = (
        next(
            (
                item
                for item in session.exercises
                if item.status != "completed"
            ),
            None,
        )
        if session is not None
        else None
    )

    return {
        "today": today.isoformat(),
        "scheduled_today": scheduled_today,
        "state": session.status if session is not None else "not_generated",
        "session": serialize_session(session) if session is not None else None,
        "previous_session": (
            serialize_session(previous_session)
            if previous_session is not None
            else None
        ),
        "completed_today": (
            serialize_session(completed_today)
            if completed_today is not None
            else None
        ),
        "next_session_exercise_id": (
            next_item.id if next_item is not None else None
        ),
        "completed_exercise_count": (
            sum(item.status == "completed" for item in session.exercises)
            if session is not None
            else 0
        ),
    }
