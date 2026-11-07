from sqlalchemy.orm import Session

from application_layer.training_management.session_result_calculator import (
    build_session_result,
)
from data_and_integration_layer.database.models.exercise_attempt import (
    ExerciseAttempt,
)
from data_and_integration_layer.database.models.practice_session import (
    PracticeSession,
)
from data_and_integration_layer.database.models.session_result import (
    SessionResult,
)

# NOTE: this module must not import practice_session_service
# (practice_session_service imports this one).


def get_latest_attempts_by_item(
    db: Session,
    item_ids: list[int],
) -> dict[int, ExerciseAttempt]:
    """Latest attempt for each session exercise id."""

    if not item_ids:
        return {}

    attempts = (
        db.query(ExerciseAttempt)
        .filter(ExerciseAttempt.session_exercise_id.in_(item_ids))
        .order_by(
            ExerciseAttempt.created_at.desc(),
            ExerciseAttempt.id.desc(),
        )
        .all()
    )

    latest: dict[int, ExerciseAttempt] = {}

    for attempt in attempts:
        latest.setdefault(attempt.session_exercise_id, attempt)

    return latest


def _attempt_to_row(attempt: ExerciseAttempt, item) -> dict:
    feedback = attempt.feedback or {}
    technique = feedback.get("technique") or {}

    return {
        "total_score": attempt.total_score,
        "fluency_score": attempt.fluency_score,
        "rhythm_score": attempt.rhythm_score,
        "speed_control_score": attempt.speed_control_score,
        "task_adherence_score": attempt.task_adherence_score,
        "stuttering_percent": attempt.stuttering_percent,
        "repetition_percent": attempt.repetition_percent,
        "prolongation_percent": attempt.prolongation_percent,
        "block_percent": attempt.block_percent,
        "audio_duration_seconds": attempt.audio_duration_seconds,
        "technique_status": technique.get("status"),
        "title": (item.exercise_snapshot or {}).get("title"),
        "strength": feedback.get("strength"),
        "improvement": feedback.get("improvement"),
    }


def ensure_session_result(
    db: Session,
    session: PracticeSession,
) -> SessionResult | None:
    """Create the session result once, when every exercise has an attempt.

    Idempotent. Flushes but never commits: the caller owns the transaction.
    Returns None when the session is not completed or an attempt is missing.
    """

    if session.status != "completed":
        return None

    existing = (
        db.query(SessionResult)
        .filter(SessionResult.session_id == session.id)
        .one_or_none()
    )

    if existing is not None:
        return existing

    items = list(session.exercises)

    latest = get_latest_attempts_by_item(
        db,
        [item.id for item in items],
    )

    if not items or any(item.id not in latest for item in items):
        return None

    previous = (
        db.query(SessionResult)
        .join(
            PracticeSession,
            PracticeSession.id == SessionResult.session_id,
        )
        .filter(
            SessionResult.user_id == session.user_id,
            PracticeSession.sequence_number < session.sequence_number,
        )
        .order_by(PracticeSession.sequence_number.desc())
        .first()
    )

    values = build_session_result(
        attempts=[
            _attempt_to_row(latest[item.id], item) for item in items
        ],
        previous_total_score=(
            previous.total_score if previous is not None else None
        ),
    )

    result = SessionResult(
        session_id=session.id,
        user_id=session.user_id,
        **values,
    )

    db.add(result)
    db.flush()

    return result
