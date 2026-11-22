from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from application_layer.training_management.session_result_service import (
    get_latest_attempts_by_item,
)
from data_and_integration_layer.database.models.practice_session import (
    PracticeSession,
    PracticeSessionExercise,
)
from data_and_integration_layer.database.models.session_result import (
    SessionResult,
)


RIYADH_TIMEZONE = timezone(timedelta(hours=3))

PERIODS = {"week", "month", "all"}


def _period_start(period: str, today: date) -> date | None:
    """First day of the period, or None for all time.

    The week starts on Sunday, the same as the practice streak.
    """

    if period == "week":
        return today - timedelta(days=(today.weekday() + 1) % 7)

    if period == "month":
        return today.replace(day=1)

    return None


def get_session_progress_summary(
    db: Session,
    user_id: int,
    period: str = "all",
) -> dict:
    """Progress numbers over the user's completed sessions.

    - completed_sessions: number of completed sessions in the period.
    - total_training_seconds: recorded speaking time of the latest attempt
      of every exercise in those sessions.
    - latest / best score across those sessions.
    - stuttering_series: stuttering percentage per session, oldest first,
      so the app can draw how it changes over time.
    """

    if period not in PERIODS:
        period = "all"

    today = datetime.now(RIYADH_TIMEZONE).date()
    start = _period_start(period, today)

    query = (
        db.query(SessionResult, PracticeSession)
        .join(
            PracticeSession,
            PracticeSession.id == SessionResult.session_id,
        )
        .filter(SessionResult.user_id == user_id)
    )

    if start is not None:
        query = query.filter(PracticeSession.practice_date >= start)

    rows = query.order_by(
        PracticeSession.practice_date.asc(),
        PracticeSession.id.asc(),
    ).all()

    session_ids = [session.id for _, session in rows]

    item_ids = []

    if session_ids:
        item_ids = [
            item_id
            for (item_id,) in db.query(PracticeSessionExercise.id)
            .filter(PracticeSessionExercise.session_id.in_(session_ids))
            .all()
        ]

    latest_attempts = get_latest_attempts_by_item(db, item_ids)

    total_seconds = sum(
        attempt.audio_duration_seconds or 0
        for attempt in latest_attempts.values()
    )

    series = [
        {
            "session_id": session.id,
            "sequence_number": session.sequence_number,
            "practice_date": session.practice_date.isoformat(),
            "stuttering_percent": result.stuttering_percent,
            "total_score": result.total_score,
        }
        for result, session in rows
    ]

    latest = series[-1] if series else None
    best = max(series, key=lambda item: item["total_score"], default=None)

    stuttering_change = None

    if len(series) >= 2:
        stuttering_change = round(
            series[-1]["stuttering_percent"]
            - series[0]["stuttering_percent"],
            1,
        )

    # Change of each stuttering pattern between the first and the last
    # session of the period (negative = better).
    pattern_changes = None

    if len(rows) >= 2:
        first_result = rows[0][0]
        last_result = rows[-1][0]

        pattern_changes = {
            name: round(
                getattr(last_result, f"{name}_percent")
                - getattr(first_result, f"{name}_percent"),
                1,
            )
            for name in ("repetition", "prolongation", "block")
        }

    return {
        "period": period,
        "period_start": start.isoformat() if start else None,
        "completed_sessions": len(rows),
        "total_training_seconds": int(total_seconds),
        "latest_score": latest["total_score"] if latest else None,
        "latest_session_id": latest["session_id"] if latest else None,
        "best_score": best["total_score"] if best else None,
        "best_session_id": best["session_id"] if best else None,
        "stuttering_change": stuttering_change,
        "pattern_changes": pattern_changes,
        "stuttering_series": [
            {
                "session_id": item["session_id"],
                "sequence_number": item["sequence_number"],
                "practice_date": item["practice_date"],
                "stuttering_percent": item["stuttering_percent"],
            }
            for item in series
        ],
    }
