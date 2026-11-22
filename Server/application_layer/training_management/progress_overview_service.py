from collections import defaultdict
from datetime import datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session


RIYADH_TIMEZONE = timezone(timedelta(hours=3))

PATTERNS = ("repetition", "prolongation", "block")

# Arabic names of the exercise types, as shown in the Training tab.
EXERCISE_TYPE_NAMES = {
    "Reading": "القراءة",
    "Picture Description": "وصف الصورة",
    "Question & Answer": "الأسئلة والأجوبة",
    "Storytelling": "رواية القصة",
    "Free Speech": "التحدث الحر",
}

SCENARIO_NAME = "مواقف الحياة"
DONT_SAY_IT_NAME = "لا تقولها"
NAMING_CHALLENGE_NAME = "تحدي التعداد"

# Speech-analysis JSON of the two games (same analyzer as the exercises).
GAME_ANALYSIS_QUERY = """
    SELECT
        created_at,
        (speech_analysis->>'stuttering_percent')::float AS stuttering,
        (speech_analysis->>'repetition_percent')::float AS repetition,
        (speech_analysis->>'prolongation_percent')::float AS prolongation,
        (speech_analysis->>'block_percent')::float AS block
    FROM {table}
    WHERE user_id::text = :user_id
      AND speech_analysis IS NOT NULL
      AND speech_analysis->>'stuttering_percent' IS NOT NULL
    ORDER BY created_at ASC, id ASC
"""


def _aware(value: datetime) -> datetime:
    """Database timestamps are UTC; some columns have no time zone."""

    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)

    return value


def _riyadh_date(value: datetime) -> str:
    """Calendar date (Riyadh time) of a database timestamp (UTC)."""

    return _aware(value).astimezone(RIYADH_TIMEZONE).date().isoformat()


def _daily_average(points: list[tuple[str, float]]) -> list[dict]:
    """One point per day: the average stuttering percent of that day."""

    by_day: dict[str, list[float]] = defaultdict(list)

    for day, percent in points:
        by_day[day].append(percent)

    return [
        {
            "date": day,
            "stuttering_percent": round(sum(values) / len(values), 1),
        }
        for day, values in sorted(by_day.items())
    ]


def _pattern_changes(first: dict | None, last: dict | None) -> dict | None:
    """Change of each pattern from the first to the last result."""

    if first is None or last is None:
        return None

    return {
        name: round(last[name] - first[name], 1)
        for name in PATTERNS
        if first.get(name) is not None and last.get(name) is not None
    }


def get_progress_overview(db: Session, user_id: int) -> dict:
    """Sessions and training numbers for the Progress "Overview" tab.

    The assessments are not read here: the app already has them.

    - sessions_series: stuttering % of each completed session.
    - training_series: daily average stuttering % of every exercise,
      real-life scenario and game attempt.
    - *_pattern_changes: change of repetition / prolongation / block
      between the first and the last result (negative = better).
    - types: first and last stuttering % of every exercise type,
      scenario and game.
    """

    uid = str(user_id)

    # --- Sessions (one point per completed session) ---------------------
    session_rows = db.execute(
        text("""
            SELECT
                s.practice_date,
                r.stuttering_percent,
                r.repetition_percent,
                r.prolongation_percent,
                r.block_percent
            FROM session_results AS r
            JOIN practice_sessions AS s ON s.id = r.session_id
            WHERE r.user_id::text = :user_id
            ORDER BY s.practice_date ASC, s.id ASC
        """),
        {"user_id": uid},
    ).mappings().all()

    sessions_series = [
        {
            "date": row["practice_date"].isoformat(),
            "stuttering_percent": round(row["stuttering_percent"], 1),
        }
        for row in session_rows
    ]

    sessions_patterns = None

    if len(session_rows) >= 2:
        sessions_patterns = _pattern_changes(
            {name: session_rows[0][f"{name}_percent"] for name in PATTERNS},
            {name: session_rows[-1][f"{name}_percent"] for name in PATTERNS},
        )

    # --- Training attempts ----------------------------------------------
    # Every entry: (type name, date, stuttering, repetition, prolongation,
    # block), oldest first.
    attempts: list[tuple] = []

    exercise_rows = db.execute(
        text("""
            SELECT
                exercise_type,
                created_at,
                stuttering_percent,
                repetition_percent,
                prolongation_percent,
                block_percent
            FROM exercise_attempts
            WHERE user_id::text = :user_id
            ORDER BY created_at ASC, id ASC
        """),
        {"user_id": uid},
    ).mappings().all()

    for row in exercise_rows:
        attempts.append(
            (
                EXERCISE_TYPE_NAMES.get(
                    row["exercise_type"],
                    row["exercise_type"],
                ),
                row["created_at"],
                row["stuttering_percent"],
                row["repetition_percent"],
                row["prolongation_percent"],
                row["block_percent"],
            )
        )

    # Real-life scenarios keep their analysis in a JSON column.
    scenario_rows = db.execute(
        text("""
            SELECT
                COALESCE(ended_at, started_at) AS happened_at,
                (analysis_result->'metrics'->>'stuttering_percent')::float
                    AS stuttering,
                (analysis_result->'metrics'->>'repetition_percent')::float
                    AS repetition,
                (analysis_result->'metrics'->>'prolongation_percent')::float
                    AS prolongation,
                (analysis_result->'metrics'->>'block_percent')::float
                    AS block
            FROM scenario_attempts
            WHERE user_id::text = :user_id
              AND analysis_result IS NOT NULL
              AND analysis_result->'metrics'->>'stuttering_percent'
                  IS NOT NULL
            ORDER BY COALESCE(ended_at, started_at) ASC, id ASC
        """),
        {"user_id": uid},
    ).mappings().all()

    for row in scenario_rows:
        attempts.append(
            (
                SCENARIO_NAME,
                row["happened_at"],
                row["stuttering"],
                row["repetition"],
                row["prolongation"],
                row["block"],
            )
        )

    # The two games keep the speech analysis in a JSON column too.
    # A game table may not exist yet for a new database: skip it then.
    for table, name in (
        ("dont_say_it_attempts", DONT_SAY_IT_NAME),
        ("naming_challenge_attempts", NAMING_CHALLENGE_NAME),
    ):
        try:
            game_rows = db.execute(
                text(GAME_ANALYSIS_QUERY.format(table=table)),
                {"user_id": uid},
            ).mappings().all()
        except Exception:
            db.rollback()
            continue

        for row in game_rows:
            attempts.append(
                (
                    name,
                    row["created_at"],
                    row["stuttering"],
                    row["repetition"],
                    row["prolongation"],
                    row["block"],
                )
            )

    attempts.sort(key=lambda item: _aware(item[1]))

    training_series = _daily_average(
        [(_riyadh_date(item[1]), item[2]) for item in attempts]
    )

    # One point per attempt (the app compares the first and the last ones).
    training_attempts = [
        {
            "date": _riyadh_date(item[1]),
            "stuttering_percent": round(item[2], 1),
        }
        for item in attempts
    ]

    training_patterns = None

    # Patterns are compared on the exercises and scenarios, which always
    # store them (the same fields in every attempt).
    with_patterns = [
        item
        for item in attempts
        if None not in (item[3], item[4], item[5])
    ]

    if len(with_patterns) >= 2:
        training_patterns = _pattern_changes(
            dict(zip(PATTERNS, with_patterns[0][3:6])),
            dict(zip(PATTERNS, with_patterns[-1][3:6])),
        )

    # First and last result of every exercise type / scenario / game.
    by_type: dict[str, list[float]] = defaultdict(list)

    for item in attempts:
        by_type[item[0]].append(item[2])

    types = [
        {
            "name": name,
            "attempts": len(values),
            "first_percent": round(values[0], 1),
            "last_percent": round(values[-1], 1),
        }
        for name, values in by_type.items()
    ]

    return {
        "sessions_series": sessions_series,
        "sessions_pattern_changes": sessions_patterns,
        "training_series": training_series,
        "training_attempts": training_attempts,
        "training_pattern_changes": training_patterns,
        "types": types,
    }
