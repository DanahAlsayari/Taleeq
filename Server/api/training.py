import random
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from application_layer.authentication_managment.auth import (
    get_current_user,
)

router = APIRouter(
    prefix="/training",
    tags=["Training"],
)

ALLOWED_TYPES = {
    "Reading",
    "Picture Description",
    "Question & Answer",
    "Storytelling",
    "Free Speech",
}

ALLOWED_DIFFICULTIES = {
    "Easy",
    "Medium",
    "Hard",
}


@router.get("/random-exercise")
def get_random_exercise(
    exercise_type: str,
    difficulty: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    # Validate exercise type
    if exercise_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Invalid exercise type",
        )

    # Validate difficulty
    if difficulty not in ALLOWED_DIFFICULTIES:
        raise HTTPException(
            status_code=400,
            detail="Invalid difficulty",
        )

    # Get active exercises matching the selected type and difficulty
    exercises = db.execute(
        text(
            """
            SELECT
                id,
                type,
                title,
                description,
                instructions,
                difficulty,
                language,
                content
            FROM speech_exercises
            WHERE type = :exercise_type
              AND difficulty = :difficulty
              AND is_active = TRUE
            """
        ),
        {
            "exercise_type": exercise_type,
            "difficulty": difficulty,
        },
    ).mappings().all()

    if not exercises:
        raise HTTPException(
            status_code=404,
            detail="No exercises available for this type and difficulty",
        )

    # Get exercises previously completed by the current user
    seen_rows = db.execute(
        text(
            """
            SELECT exercise_id
            FROM user_seen_exercises
            WHERE user_id = :user_id
            """
        ),
        {"user_id": current_user.id},
    ).scalars().all()

    # Normalize IDs to strings before comparison
    seen_ids = {str(exercise_id) for exercise_id in seen_rows}

    # Exclude previously completed exercises
    unseen_exercises = [
        exercise
        for exercise in exercises
        if str(exercise["id"]) not in seen_ids
    ]

    # Start a new cycle when all matching exercises are completed
    if not unseen_exercises:
        exercise_ids = [str(exercise["id"]) for exercise in exercises]

        db.execute(
            text(
                """
                DELETE FROM user_seen_exercises
                WHERE user_id = :user_id
                  AND exercise_id = ANY(CAST(:exercise_ids AS uuid[]))
                """
            ),
            {
                "user_id": current_user.id,
                "exercise_ids": exercise_ids,
            },
        )
        db.commit()

        unseen_exercises = exercises

    # Select one random exercise
    selected = random.choice(unseen_exercises)

    return {
        "id": str(selected["id"]),
        "type": selected["type"],
        "title": selected["title"],
        "description": selected["description"],
        "instructions": selected["instructions"],
        "difficulty": selected["difficulty"],
        "language": selected["language"],
        "content": selected["content"],
    }


@router.post("/complete-exercise/{exercise_id}")
def complete_exercise(
    exercise_id: UUID,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    # Check that the exercise exists
    exercise_exists = db.execute(
        text(
            """
            SELECT id
            FROM speech_exercises
            WHERE id = :exercise_id
            """
        ),
        {"exercise_id": str(exercise_id)},
    ).first()

    if not exercise_exists:
        raise HTTPException(
            status_code=404,
            detail="Exercise not found",
        )

    # Save completed exercise for this user
    db.execute(
        text(
            """
            INSERT INTO user_seen_exercises (user_id, exercise_id)
            VALUES (:user_id, :exercise_id)
            ON CONFLICT (user_id, exercise_id)
            DO NOTHING
            """
        ),
        {
            "user_id": current_user.id,
            "exercise_id": str(exercise_id),
        },
    )

    db.commit()

    return {
        "message": "Exercise completed successfully",
        "exercise_id": str(exercise_id),
    }
