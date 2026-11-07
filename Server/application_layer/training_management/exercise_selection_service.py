import math
import random

from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.speech_exercise import (
    SpeechExercise,
)
from datetime import date, datetime, timedelta, timezone

from data_and_integration_layer.database.models.weekly_plan import (
    PlannedPracticeSession,
    WeeklyPlan,
    WeeklyPracticeSchedule,
)
from data_and_integration_layer.database.models.assessment import (
    Assessment,
    AssessmentTask,
    TaskAnalysisResult,
)
from data_and_integration_layer.database.models.user import User

TASK_TO_EXERCISE_TYPE = {
    "task_1": "Reading",
    "task_2": "Picture Description",
    "task_3": "Free Speech",
}

MEDIUM_MAX_STUTTERING_PERCENT = 20.0


def recommend_starting_difficulty(
    stuttering_percent: float | None,
) -> str:
    """Recommend Easy or Medium from a matching assessment task."""

    if stuttering_percent is None:
        return "Easy"

    if (
        isinstance(stuttering_percent, bool)
        or not isinstance(stuttering_percent, (int, float))
        or not math.isfinite(stuttering_percent)
        or not 0 <= stuttering_percent <= 100
    ):
        raise ValueError(
            "Stuttering percentage must be a number from 0 to 100."
        )

    if stuttering_percent <= MEDIUM_MAX_STUTTERING_PERCENT:
        return "Medium"

    return "Easy"

def select_intro_exercise_types(
    task_results: list[dict],
    session_number: int = 1,
) -> list[dict]:
    """Choose three activity types before fetching actual exercises."""

    if (
        isinstance(session_number, bool)
        or not isinstance(session_number, int)
        or session_number < 1
    ):
        raise ValueError("Session number must be a positive integer.")

    results_by_type = {}

    for result in task_results:
        task_type = result.get("task_type")

        if task_type not in TASK_TO_EXERCISE_TYPE:
            continue

        if task_type in results_by_type:
            raise ValueError(f"Duplicate assessment task: {task_type}")

        percent = result.get("stuttering_percent")

        difficulty = recommend_starting_difficulty(percent)

        results_by_type[task_type] = {
            "exercise_type": TASK_TO_EXERCISE_TYPE[task_type],
            "stuttering_percent": percent,
            "difficulty": difficulty,
        }

    candidates = []

    for task_type, exercise_type in TASK_TO_EXERCISE_TYPE.items():
        candidates.append(
            results_by_type.get(
                task_type,
                {
                    "exercise_type": exercise_type,
                    "stuttering_percent": None,
                    "difficulty": "Easy",
                },
            )
        )

    ranked = sorted(
        candidates,
        key=lambda item: (
            item["stuttering_percent"] is not None,
            item["stuttering_percent"]
            if item["stuttering_percent"] is not None
            else -1,
        ),
        reverse=True,
    )

    second_index = 1 + ((session_number - 1) % 2)

    variety_type = (
        "Question & Answer"
        if session_number % 2 == 1
        else "Storytelling"
    )

    return [
        {**ranked[0], "selection_role": "focus"},
        {**ranked[second_index], "selection_role": "second_activity"},
        {
            "exercise_type": variety_type,
            "stuttering_percent": None,
            "difficulty": "Easy",
            "selection_role": "variety",
        },
    ]

ESTIMATED_EXERCISE_SECONDS = 5 * 60


def build_exercise_preview(
    db: Session,
    task_results: list[dict],
    duration_minutes: int | None = None,
    session_number: int = 1,
) -> dict:
    """Select distinct exercises using a provisional five-minute estimate."""

    if duration_minutes is not None:
        if (
            isinstance(duration_minutes, bool)
            or not isinstance(duration_minutes, int)
            or not 5 <= duration_minutes <= 120
        ):
            raise ValueError(
                "Duration must be a whole number from 5 to 120 minutes."
            )

    priorities = select_intro_exercise_types(
        task_results,
        session_number=session_number,
    )

    # Optional sessions contain the original three activities.
    # Scheduled sessions can include all five types before repeating.
    if duration_minutes is not None:
        included_types = {
            item["exercise_type"] for item in priorities
        }
        percentages = {
            TASK_TO_EXERCISE_TYPE[result["task_type"]]:
                result.get("stuttering_percent")
            for result in task_results
            if result.get("task_type") in TASK_TO_EXERCISE_TYPE
        }

        for exercise_type in [
            "Reading",
            "Picture Description",
            "Free Speech",
            "Question & Answer",
            "Storytelling",
        ]:
            if exercise_type in included_types:
                continue

            percent = percentages.get(exercise_type)

            priorities.append(
                {
                    "exercise_type": exercise_type,
                    "difficulty": recommend_starting_difficulty(percent),
                    "selection_role": "additional_variety",
                }
            )

    exercise_limit = (
        duration_minutes // 5
        if duration_minutes is not None
        else 3
    )

    pools = []

    for priority in priorities:
        exercises = (
            db.query(SpeechExercise)
            .filter(
                SpeechExercise.is_active.is_(True),
                SpeechExercise.language == "ar",
                SpeechExercise.type == priority["exercise_type"],
                SpeechExercise.difficulty == priority["difficulty"],
            )
            .order_by(SpeechExercise.sort_order, SpeechExercise.id)
            .all()
        )

        candidates = []

        for exercise in exercises:
            content = exercise.content

            if not isinstance(content, dict):
                continue

            recording_seconds = content.get("target_duration_seconds")

            if (
                isinstance(recording_seconds, bool)
                or not isinstance(recording_seconds, (int, float))
                or not math.isfinite(recording_seconds)
                or recording_seconds <= 0
            ):
                continue

            candidates.append(
                (exercise, math.ceil(recording_seconds))
            )

        random.shuffle(candidates)
        pools.append((priority, candidates))

    unavailable_types = [
        priority["exercise_type"]
        for priority, candidates in pools
        if not candidates
    ]

    if duration_minutes is None and unavailable_types:
        raise ValueError(
            "No usable active exercise available for: "
            + ", ".join(unavailable_types)
        )

    selected = []
    selected_ids = set()

    # Visit every priority once before repeating types.
    while len(selected) < exercise_limit:
        added_any = False

        for priority, candidates in pools:
            if len(selected) >= exercise_limit:
                break

            while candidates:
                exercise, recording_seconds = candidates.pop()

                if exercise.id in selected_ids:
                    continue

                selected.append(
                    {
                        "exercise_id": str(exercise.id),
                        "position": len(selected) + 1,
                        "exercise_type": exercise.type,
                        "difficulty": exercise.difficulty,
                        "title": exercise.title,
                        "instructions": exercise.instructions,
                        "content": exercise.content,
                        "selection_role": priority["selection_role"],
                        "target_recording_seconds": recording_seconds,
                        "estimated_duration_seconds":
                            ESTIMATED_EXERCISE_SECONDS,
                    }
                )
                selected_ids.add(exercise.id)
                added_any = True
                break

        if not added_any:
            break

    if not selected:
        raise ValueError(
            "No suitable exercise fits the selected recording-time budget."
        )

    estimated_seconds = len(selected) * ESTIMATED_EXERCISE_SECONDS

    return {
        "selection_mode": (
            "estimated_time_budget"
            if duration_minutes is not None
            else "three_exercises"
        ),
        "target_duration_minutes": duration_minutes,
        "estimated_duration_seconds": estimated_seconds,
        "total_target_recording_seconds": sum(
            item["target_recording_seconds"] for item in selected
        ),
        "remaining_estimated_budget_seconds": (
            duration_minutes * 60 - estimated_seconds
            if duration_minutes is not None
            else None
        ),
        "unavailable_exercise_types": unavailable_types,
        "exercise_count": len(selected),
        "exercises": selected,
    }
def get_schedule_for_date(
    db: Session,
    user_id: int,
    practice_date: date,
) -> dict:
    """Read a user's dated schedule without creating records."""

    day_offset = (practice_date.weekday() + 1) % 7
    week_start = practice_date - timedelta(days=day_offset)

    plan = (
        db.query(WeeklyPlan)
        .filter(
            WeeklyPlan.user_id == user_id,
            WeeklyPlan.week_start == week_start,
        )
        .one_or_none()
    )

    if plan is not None:
        scheduled = (
            db.query(PlannedPracticeSession)
            .filter(
                PlannedPracticeSession.plan_id == plan.id,
                PlannedPracticeSession.practice_date == practice_date,
            )
            .one_or_none()
        )

        return {
            "duration_minutes": (
                scheduled.duration_minutes
                if scheduled is not None
                else None
            ),
            "planned_practice_session_id": (
                scheduled.id if scheduled is not None else None
            ),
        }

    # Only use the repeating template for today's week.
    # It must not reconstruct historical schedules.
    today = datetime.now(
        timezone(timedelta(hours=3))
    ).date()
    current_week = today - timedelta(
        days=(today.weekday() + 1) % 7
    )

    if week_start == current_week:
        schedule = (
            db.query(WeeklyPracticeSchedule)
            .filter(
                WeeklyPracticeSchedule.user_id == user_id,
            )
            .one_or_none()
        )

        if schedule is not None:
            for item in schedule.sessions:
                if item["day_offset"] == day_offset:
                    return {
                        "duration_minutes": item["duration_minutes"],
                        "planned_practice_session_id": None,
                    }

    return {
        "duration_minutes": None,
        "planned_practice_session_id": None,
    }


def preview_today_exercises(
    db: Session,
    user_id: int,
    task_results: list[dict],
    session_number: int = 1,
    additional_session: bool = False,
) -> dict:
    """Build a preview using today's schedule when applicable."""

    today = datetime.now(
        timezone(timedelta(hours=3))
    ).date()

    schedule = {
        "duration_minutes": None,
        "planned_practice_session_id": None,
    }

    if not additional_session:
        schedule = get_schedule_for_date(
            db=db,
            user_id=user_id,
            practice_date=today,
        )

    preview = build_exercise_preview(
        db=db,
        task_results=task_results,
        duration_minutes=schedule["duration_minutes"],
        session_number=session_number,
    )

    return {
        **preview,
        "practice_date": today.isoformat(),
        "planned_practice_session_id": schedule[
            "planned_practice_session_id"
        ],
        "additional_session": additional_session,
    }
def preview_personalized_session(
    db: Session,
    user_id: int,
    session_number: int = 1,
    additional_session: bool = False,
) -> dict:
    """Build a preview from the user's latest completed assessment."""

    assessment = (
        db.query(Assessment)
        .filter(
            Assessment.user_id == user_id,
            Assessment.status.in_(["COMPLETED", "completed"]),
            Assessment.completed_at.isnot(None),
        )
        .order_by(
            Assessment.completed_at.desc(),
            Assessment.id.desc(),
        )
        .first()
    )

    if assessment is None:
        raise ValueError(
            "Complete a speech assessment before generating a session."
        )

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
            AssessmentTask.assessment_id == assessment.id,
            AssessmentTask.task_type.in_(
                list(TASK_TO_EXERCISE_TYPE)
            ),
        )
        .all()
    )

    if not rows:
        raise ValueError(
            "The latest completed assessment has no usable task results."
        )

    task_results = [
        {
            "task_type": row.task_type,
            "stuttering_percent": row.stuttering_percent,
        }
        for row in rows
    ]

    preview = preview_today_exercises(
        db=db,
        user_id=user_id,
        task_results=task_results,
        session_number=session_number,
        additional_session=additional_session,
    )

    return {
        **preview,
        "assessment_id": assessment.id,
        "session_number": session_number,
    }