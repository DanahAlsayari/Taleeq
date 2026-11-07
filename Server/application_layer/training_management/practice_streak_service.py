from datetime import date, datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session


RIYADH_TIMEZONE = timezone(timedelta(hours=3))


def summarize_practice_days(
    practice_days: set[date],
    today: date,
) -> dict:
    """Count consecutive practice days, allowing today to remain unfinished."""

    days = sorted(day for day in practice_days if day <= today)
    day_set = set(days)

    current_streak = 0
    cursor = today if today in day_set else today - timedelta(days=1)

    while cursor in day_set:
        current_streak += 1
        cursor -= timedelta(days=1)

    longest_streak = 0
    run = 0
    previous = None

    for day in days:
        run = run + 1 if previous == day - timedelta(days=1) else 1
        longest_streak = max(longest_streak, run)
        previous = day
    week_start = today - timedelta(days=(today.weekday() + 1) % 7)
    week_days = [
        day.isoformat()
        for day in days
        if week_start <= day <= today
    ]

    return {
        "today": today.isoformat(),
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "practiced_today": today in day_set,
        "last_practice_date": days[-1].isoformat() if days else None,
        "total_practice_days": len(days),
        "week_practice_dates": week_days,
        "week_practice_count": len(week_days),
    }


def get_practice_streak(db: Session, user_id: int) -> dict:
    """Read completed activity dates without creating or changing records."""

    rows = db.execute(
        text("""
            SELECT DISTINCT practice_date
            FROM (
                SELECT
                    (
                        created_at AT TIME ZONE 'UTC'
                        AT TIME ZONE 'Asia/Riyadh'
                    )::date AS practice_date
                FROM exercise_attempts
                WHERE user_id = :user_id

                UNION ALL

                SELECT
                    (
                        created_at AT TIME ZONE 'Asia/Riyadh'
                    )::date AS practice_date
                FROM dont_say_it_attempts
                WHERE user_id = CAST(:user_id AS TEXT)

                UNION ALL

                SELECT
                    (
                        created_at AT TIME ZONE 'UTC'
                        AT TIME ZONE 'Asia/Riyadh'
                    )::date AS practice_date
                FROM naming_challenge_attempts
                WHERE user_id = CAST(:user_id AS TEXT)

                UNION ALL

                SELECT
                    (
                        ended_at AT TIME ZONE 'UTC'
                        AT TIME ZONE 'Asia/Riyadh'
                    )::date AS practice_date
                FROM scenario_attempts
                WHERE user_id = :user_id
                  AND status = 'completed'
                  AND end_reason = 'scenario_completed'
                  AND ended_at IS NOT NULL
            ) AS completed_activities
            WHERE practice_date IS NOT NULL
        """),
        {"user_id": user_id},
    ).scalars().all()

    today = datetime.now(RIYADH_TIMEZONE).date()

    return summarize_practice_days(set(rows), today)