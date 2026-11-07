from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, selectinload

from application_layer.authentication_managment.auth import (
    get_current_user,
)
from application_layer.training_management.session_result_service import (
    ensure_session_result,
    get_latest_attempts_by_item,
)
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.exercise_attempt import (
    ExerciseAttempt,
)
from data_and_integration_layer.database.models.practice_session import (
    PracticeSession,
)
from data_and_integration_layer.database.models.session_result import (
    SessionResult,
)
from data_and_integration_layer.database.models.technique import Technique
from data_and_integration_layer.database.models.user import User


# Must be included BEFORE practice_sessions_router in main.py, so that
# "/practice-sessions/history" is not captured by "/{session_id}".
router = APIRouter(
    prefix="/practice-sessions",
    tags=["Session Results"],
)


def _get_owned_session(
    db: Session,
    user_id: int,
    session_id: int,
) -> PracticeSession:
    session = (
        db.query(PracticeSession)
        .options(selectinload(PracticeSession.exercises))
        .filter(
            PracticeSession.id == session_id,
            PracticeSession.user_id == user_id,
        )
        .one_or_none()
    )

    if session is None:
        raise HTTPException(
            status_code=404,
            detail="Practice session not found.",
        )

    return session


def _serialize_result(result: SessionResult) -> dict:
    return {
        "scores": {
            "total_score": result.total_score,
            "fluency_score": result.fluency_score,
            "rhythm_score": result.rhythm_score,
            "speed_control_score": result.speed_control_score,
            "task_adherence_score": result.task_adherence_score,
        },
        "metrics": {
            "stuttering_percent": result.stuttering_percent,
            "repetition_percent": result.repetition_percent,
            "prolongation_percent": result.prolongation_percent,
            "block_percent": result.block_percent,
        },
        "exercise_count": result.exercise_count,
        "comparison": {
            "previous_score": result.previous_total_score,
            "current_score": result.total_score,
            "score_change": result.score_change,
        },
        "feedback": result.feedback,
        "technique_summary": result.technique_summary,
        "created_at": result.created_at.isoformat(),
    }


def _technique_names(db: Session, technique_ids: set[int]) -> dict:
    if not technique_ids:
        return {}

    rows = (
        db.query(Technique)
        .filter(Technique.id.in_(technique_ids))
        .all()
    )

    return {row.id: row for row in rows}


@router.get("/history")
def read_session_history(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Completed sessions with their result, newest first.

    Used by the Progress tab. Sessions whose result has not been created
    yet appear after GET /{session_id}/result is called once.
    """

    rows = (
        db.query(SessionResult, PracticeSession)
        .join(
            PracticeSession,
            PracticeSession.id == SessionResult.session_id,
        )
        .filter(SessionResult.user_id == current_user.id)
        .order_by(
            PracticeSession.completed_at.desc(),
            PracticeSession.id.desc(),
        )
        .limit(limit)
        .offset(offset)
        .all()
    )

    return {
        "limit": limit,
        "offset": offset,
        "sessions": [
            {
                "session_id": session.id,
                "sequence_number": session.sequence_number,
                "practice_date": session.practice_date.isoformat(),
                "completed_at": (
                    session.completed_at.isoformat()
                    if session.completed_at
                    else None
                ),
                "exercise_count": result.exercise_count,
                "total_score": result.total_score,
                "score_change": result.score_change,
            }
            for result, session in rows
        ],
    }


@router.get("/{session_id}/result")
def read_session_result(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Session result plus one row per exercise.

    status is "ready" once the session result exists, otherwise "pending"
    (some exercises are not analyzed yet). The exercises list is always
    returned, so a loading screen can poll this same endpoint.
    """

    session = _get_owned_session(db, current_user.id, session_id)

    result = ensure_session_result(db, session)

    if result is not None:
        db.commit()
        db.refresh(result)

    items = list(session.exercises)
    latest = get_latest_attempts_by_item(db, [item.id for item in items])
    techniques = _technique_names(
        db,
        {item.technique_id for item in items if item.technique_id},
    )

    exercises = []

    for item in items:
        attempt = latest.get(item.id)
        technique = techniques.get(item.technique_id)
        technique_feedback = (
            (attempt.feedback or {}).get("technique") if attempt else None
        ) or {}

        exercises.append(
            {
                "session_exercise_id": item.id,
                "exercise_id": str(item.exercise_id),
                "position": item.position,
                "title": item.exercise_snapshot.get("title"),
                "exercise_type": item.exercise_snapshot.get("exercise_type"),
                "difficulty": item.exercise_snapshot.get("difficulty"),
                "status": item.status,
                "technique_id": item.technique_id,
                "technique_name": (
                    technique.name_ar if technique else None
                ),
                "technique_status": technique_feedback.get("status"),
                "attempt_id": str(attempt.id) if attempt else None,
                "total_score": attempt.total_score if attempt else None,
            }
        )

    return {
        "session_id": session.id,
        "session_status": session.status,
        "sequence_number": session.sequence_number,
        "practice_date": session.practice_date.isoformat(),
        "status": "ready" if result is not None else "pending",
        "exercise_count": len(items),
        "completed_exercise_count": sum(
            item.status == "completed" for item in items
        ),
        "result": _serialize_result(result) if result is not None else None,
        "exercises": exercises,
    }


@router.get("/{session_id}/exercises/{session_exercise_id}/result")
def read_session_exercise_result(
    session_id: int,
    session_exercise_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Full result of one exercise inside a session (details sheet)."""

    session = _get_owned_session(db, current_user.id, session_id)

    item = next(
        (
            candidate
            for candidate in session.exercises
            if candidate.id == session_exercise_id
        ),
        None,
    )

    if item is None:
        raise HTTPException(
            status_code=404,
            detail="Session exercise not found.",
        )

    attempt = get_latest_attempts_by_item(db, [item.id]).get(item.id)

    exercise = {
        "title": item.exercise_snapshot.get("title"),
        "exercise_type": item.exercise_snapshot.get("exercise_type"),
        "difficulty": item.exercise_snapshot.get("difficulty"),
    }

    if attempt is None:
        return {
            "session_id": session.id,
            "session_exercise_id": item.id,
            "status": "pending",
            "exercise": exercise,
            "result": None,
        }

    previous = (
        db.query(ExerciseAttempt)
        .filter(
            ExerciseAttempt.user_id == current_user.id,
            ExerciseAttempt.exercise_type == attempt.exercise_type,
            ExerciseAttempt.difficulty == attempt.difficulty,
            ExerciseAttempt.created_at < attempt.created_at,
        )
        .order_by(
            ExerciseAttempt.created_at.desc(),
            ExerciseAttempt.id.desc(),
        )
        .first()
    )

    previous_score = previous.total_score if previous is not None else None

    feedback = dict(attempt.feedback or {})
    technique_feedback = feedback.pop("technique", None)

    technique = None

    if item.technique_id is not None:
        row = db.query(Technique).filter(
            Technique.id == item.technique_id
        ).first()

        if row is not None:
            technique = {
                "id": row.id,
                "name_ar": row.name_ar,
                "name_en": row.name_en,
                "description": row.description,
                "status": (technique_feedback or {}).get("status"),
                "applied_where": (technique_feedback or {}).get(
                    "applied_where", []
                ),
                "improve_where": (technique_feedback or {}).get(
                    "improve_where", []
                ),
                "tip": (technique_feedback or {}).get("tip", ""),
            }

    return {
        "session_id": session.id,
        "session_exercise_id": item.id,
        "status": "ready",
        "exercise": exercise,
        "result": {
            "attempt_id": str(attempt.id),
            "scores": {
                "fluency_score": attempt.fluency_score,
                "rhythm_score": attempt.rhythm_score,
                "speed_control_score": attempt.speed_control_score,
                "task_adherence_score": attempt.task_adherence_score,
                "total_score": attempt.total_score,
            },
            "metrics": {
                "stuttering_percent": attempt.stuttering_percent,
                "repetition_percent": attempt.repetition_percent,
                "prolongation_percent": attempt.prolongation_percent,
                "block_percent": attempt.block_percent,
            },
            "feedback": feedback,
            "technique": technique,
            "speech_events": (
                (attempt.raw_openai_response or {}).get("speech_events", [])
            ),
            "comparison": {
                "previous_score": previous_score,
                "current_score": attempt.total_score,
                "score_change": (
                    round(attempt.total_score - previous_score, 2)
                    if previous_score is not None
                    else None
                ),
            },
            "audio_duration_seconds": attempt.audio_duration_seconds,
        },
    }
