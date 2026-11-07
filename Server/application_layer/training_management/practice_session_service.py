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
    get_schedule_for_date,
    build_exercise_preview,
)
from data_and_integration_layer.database.models.technique import Technique
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session, selectinload
from data_and_integration_layer.database.models.assessment import (
    AssessmentTask,
    TaskAnalysisResult,
)
from data_and_integration_layer.database.models.exercise_attempt import (
    ExerciseAttempt,
)
from application_layer.training_management.technique_recommendation_service import (
    TechniqueRecommendationService,
)


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

        # Resume an unfinished session, including one from a previous day.
        existing = (
            db.query(PracticeSession)
            .filter(
                PracticeSession.user_id == user_id,
                PracticeSession.status.in_(["ready", "in_progress"]),
            )
            .order_by(PracticeSession.sequence_number.desc())
            .first()
        )

        # Reopening today's main session must not generate another one.
        if existing is None and not additional_session:
            existing = (
                db.query(PracticeSession)
                .filter(
                    PracticeSession.user_id == user_id,
                    PracticeSession.practice_date == today,
                    PracticeSession.additional_session.is_(False),
                    PracticeSession.status == "completed",
                )
                .order_by(PracticeSession.sequence_number.desc())
                .first()
            )

        if existing is not None:
            refresh_unstarted_session(db, existing)

            response = serialize_session(existing)
            db.commit()
            return response

        last_sequence = (
            db.query(func.max(PracticeSession.sequence_number))
            .filter(PracticeSession.user_id == user_id)
            .scalar()
        )

        sequence_number = (last_sequence or 0) + 1

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

        refresh_unstarted_session(db, session)

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

    db.flush()

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
    """Read homepage state without creating or changing records."""

    today = datetime.now(timezone(timedelta(hours=3))).date()

    # Unfinished sessions take priority, including previous-day sessions.
    session = (
        db.query(PracticeSession)
        .options(selectinload(PracticeSession.exercises))
        .filter(
            PracticeSession.user_id == user_id,
            PracticeSession.status.in_(["ready", "in_progress"]),
        )
        .order_by(PracticeSession.sequence_number.desc())
        .first()
    )

    if session is None:
        session = (
            db.query(PracticeSession)
            .options(selectinload(PracticeSession.exercises))
            .filter(
                PracticeSession.user_id == user_id,
                PracticeSession.practice_date == today,
                PracticeSession.status == "completed",
            )
            .order_by(PracticeSession.sequence_number.desc())
            .first()
        )

    if session is None:
        return {
            "today": today.isoformat(),
            "state": "not_generated",
            "session": None,
            "next_session_exercise_id": None,
            "completed_exercise_count": 0,
        }

    next_item = next(
        (item for item in session.exercises if item.status != "completed"),
        None,
    )

    return {
        "today": today.isoformat(),
        "state": session.status,
        "session": serialize_session(session),
        "next_session_exercise_id": (next_item.id if next_item is not None else None),
        "completed_exercise_count": sum(
            item.status == "completed" for item in session.exercises
        ),
    }


def refresh_unstarted_session(
    db: Session,
    session: PracticeSession,
) -> bool:
    """Refresh today's ready session inside the caller's transaction.

    The caller must hold the user lock.
    Returns True when exercise items are replaced.
    """

    today = datetime.now(timezone(timedelta(hours=3))).date()

    if (
        session.status != "ready"
        or session.started_at is not None
        or session.additional_session
        or session.practice_date != today
    ):
        return False

    # Never replace exercises that already have progress.
    if any(item.status != "pending" for item in session.exercises):
        raise PracticeSessionConflictError(
            "A session with exercise progress cannot be rebuilt."
        )

    item_ids = [item.id for item in session.exercises]

    if item_ids:
        attempt_exists = (
            db.query(ExerciseAttempt.id)
            .filter(
                ExerciseAttempt.session_exercise_id.in_(item_ids),
            )
            .first()
        )

        if attempt_exists is not None:
            raise PracticeSessionConflictError(
                "A session with saved attempts cannot be rebuilt."
            )

    schedule = get_schedule_for_date(
        db=db,
        user_id=session.user_id,
        practice_date=session.practice_date,
    )

    duration = schedule["duration_minutes"]
    planned_id = schedule["planned_practice_session_id"]

    if duration == session.target_duration_minutes:
        # The dated weekly plan may have been created since generation.
        # Update its link without changing exercises or techniques.
        session.planned_practice_session_id = planned_id
        return False

    # Keep the original assessment, even if a newer one now exists.
    rows = (
        db.query(
            AssessmentTask.task_type,
            TaskAnalysisResult.stuttering_percent,
        )
        .join(
            TaskAnalysisResult,
            TaskAnalysisResult.task_id == AssessmentTask.id,
        )
        .filter(
            AssessmentTask.assessment_id == session.assessment_id,
        )
        .all()
    )

    if not rows:
        raise PracticeSessionConflictError(
            "The session's original assessment results are unavailable."
        )

    preview = build_exercise_preview(
        db=db,
        task_results=[
            {
                "task_type": row.task_type,
                "stuttering_percent": row.stuttering_percent,
            }
            for row in rows
        ],
        duration_minutes=duration,
        session_number=session.sequence_number,
    )

    # Delete old pending items before inserting replacement positions.
    # Everything remains inside one transaction.

    saved_technique_ids = [
        item.technique_id
        for item in sorted(
            session.exercises,
            key=lambda item: item.position,
        )
    ]
    if not saved_technique_ids or any(
            technique_id is None for technique_id in saved_technique_ids
        ):
            raise PracticeSessionConflictError(
                "The session has no valid saved technique assignments."
            )
    
    session.exercises.clear()
    db.flush()

    session.exercises.extend(
        [
            PracticeSessionExercise(
                exercise_id=UUID(item["exercise_id"]),
                position=item["position"],
                selection_role=item["selection_role"],
                exercise_snapshot=dict(item),
                target_recording_seconds=item["target_recording_seconds"],
                status="pending",
                technique_id=saved_technique_ids[index % len(saved_technique_ids)],
            )
            for index, item in enumerate(preview["exercises"])
        ]
    )

    session.target_duration_minutes = duration
    session.planned_practice_session_id = planned_id

    db.flush()
    return True
