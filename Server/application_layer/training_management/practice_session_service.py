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
)
from data_and_integration_layer.database.models.technique import Technique


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
                "target_recording_seconds": (
                    item.target_recording_seconds
                ),
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
            item["target_recording_seconds"]
            for item in exercises
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

    today = datetime.now(
        timezone(timedelta(hours=3))
    ).date()

    try:
        # Serialize session creation for the same user.
        user = (
            db.query(User)
            .filter(User.id == user_id)
            .with_for_update()
            .one_or_none()
        )

        if user is None:
            raise ValueError("User not found.")

        # Resume an unfinished session, including one from a previous day.
        existing = (
            db.query(PracticeSession)
            .filter(
                PracticeSession.user_id == user_id,
                PracticeSession.status.in_(
                    ["ready", "in_progress"]
                ),
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

        session = PracticeSession(
            user_id=user_id,
            assessment_id=preview["assessment_id"],
            planned_practice_session_id=preview[
                "planned_practice_session_id"
            ],
            practice_date=today,
            sequence_number=sequence_number,
            additional_session=additional_session,
            target_duration_minutes=preview[
                "target_duration_minutes"
            ],
            status="ready",
        )

        session.exercises = [
            PracticeSessionExercise(
                exercise_id=UUID(item["exercise_id"]),
                position=item["position"],
                selection_role=item["selection_role"],
                exercise_snapshot=dict(item),
                target_recording_seconds=item[
                    "target_recording_seconds"
                ],
                status="pending",
            )
            for item in preview["exercises"]
        ]

        db.add(session)
        db.flush()

        response = serialize_session(session)
        db.commit()

        return response

    except Exception:
        db.rollback()
        raise