from sqlalchemy.orm import Session
from sqlalchemy import func

from data_and_integration_layer.database.models.exercise_attempt import ExerciseAttempt

from data_and_integration_layer.database.models.user import User
from data_and_integration_layer.database.models.scenario_attempt import ScenarioAttempt
from data_and_integration_layer.database.models.scenario_user_progress import (
    ScenarioUserProgress,
)
from data_and_integration_layer.database.models.practice_session import PracticeSession
from data_and_integration_layer.database.models.assessment import Assessment
from sqlalchemy import text


def inspect_user_data(db: Session, user_id: int) -> dict:
    user = db.query(User).filter(User.id == user_id).first()

    if user is None:
        raise ValueError("User not found.")
    
    exercise_attempts_count = (
        db.query(func.count(ExerciseAttempt.id))
        .filter(ExerciseAttempt.user_id == user_id)
        .scalar()
    )
    scenario_attempts_count = (
        db.query(func.count(ScenarioAttempt.id))
        .filter(ScenarioAttempt.user_id == user_id)
        .scalar()
    )
    scenario_progress_count = (
        db.query(func.count(ScenarioUserProgress.id))
        .filter(ScenarioUserProgress.user_id == user_id)
        .scalar()
    )
    practice_sessions_count = (
        db.query(func.count(PracticeSession.id))
        .filter(PracticeSession.user_id == user_id)
        .scalar()
    )
    return {
        "user_id": user.id,
        "assessments_count": len(user.assessments),
        "has_fluency_profile": user.fluency_profile is not None,
        "exercise_attempts_count": exercise_attempts_count,
        "scenario_attempts_count": scenario_attempts_count,
        "scenario_progress_count": scenario_progress_count,
        "practice_sessions_count": practice_sessions_count,
    }

def delete_user_account(db: Session, user_id: int) -> str | None:
    user = db.query(User).filter(User.id == user_id).first()

    if user is None:
        raise ValueError("User not found.")
    profile_picture_path = user.profile_picture_path

    db.query(ScenarioUserProgress).filter(
        ScenarioUserProgress.user_id == user_id
    ).delete(synchronize_session=False)

    db.query(ScenarioAttempt).filter(ScenarioAttempt.user_id == user_id).delete(
        synchronize_session=False
    )
    db.query(ExerciseAttempt).filter(ExerciseAttempt.user_id == user_id).delete(
        synchronize_session=False
    )
    db.query(PracticeSession).filter(PracticeSession.user_id == user_id).delete(
        synchronize_session=False
    )
    if user.fluency_profile is not None:
       db.delete(user.fluency_profile)
       db.flush()

    assessments = (
        db.query(Assessment)
        .filter(Assessment.user_id == user_id)
        .all()
    )

    for assessment in assessments:
        db.delete(assessment)

    db.flush()

    game_user_id = str(user_id)

    db.execute(
        text("""
            DELETE FROM public.dont_say_it_attempts
            WHERE user_id = :user_id
        """),
        {"user_id": game_user_id},
    )

    db.execute(
        text("""
            DELETE FROM public.naming_challenge_attempts
            WHERE user_id = :user_id
        """),
        {"user_id": game_user_id},
    )

    db.execute(
        text("""
            DELETE FROM public.naming_challenge_scores
            WHERE user_id = :user_id
        """),
        {"user_id": game_user_id},
    )

    db.delete(user)
    db.flush()
    return profile_picture_path
