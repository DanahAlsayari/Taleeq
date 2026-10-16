
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
)
from sqlalchemy.orm import Session

from application_layer.authentication_managment import auth
from application_layer.exercise_analysis.exercise_analysis_service import (
    ExerciseAnalysisService,
)
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User
from data_and_integration_layer.database.Repositories.exercise_attempt_repository import (
    ExerciseAttemptRepository,
)

router = APIRouter(
    prefix="/speech-exercises",
    tags=["Speech Exercises"],
)


@router.post("/{exercise_id}/analyze-audio")
async def analyze_exercise_audio(
    exercise_id: UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    # Read 
    audio_bytes = await file.read()

    if not audio_bytes:
        raise HTTPException(
            status_code=400,
            detail="التسجيل فارغ. أعد التسجيل.",
        )


    audio_format = (
        file.filename.rsplit(".", 1)[-1].lower()
        if file.filename and "." in file.filename
        else ""
    )

    supported_formats = {"wav", "mp3", "m4a", "webm"}

    if audio_format not in supported_formats:
        raise HTTPException(
            status_code=400,
            detail="صيغة التسجيل غير مدعومة.",
        )

    # Analyze the exercise
    service = ExerciseAnalysisService(db)

    try:
        result = service.analyze_exercise(
            user_id=current_user.id,
            exercise_id=exercise_id,
            audio_bytes=audio_bytes,
            audio_format=audio_format,
        )

    except ValueError as error:
        if str(error) == "Exercise not found.":
            raise HTTPException(
                status_code=404,
                detail="التمرين غير موجود.",
            ) from error

        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    return result


@router.get("/attempts/recent")
def get_recent_exercise_attempts(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = ExerciseAttemptRepository(db)

    attempts = repository.get_last_five_attempts(
        user_id=current_user.id,
    )

    return [
        {
            "id": str(attempt.id),
            "exercise_id": str(attempt.exercise_id),
            "exercise_type": attempt.exercise_type,
            "difficulty": attempt.difficulty,
            "created_at": attempt.created_at.isoformat(),
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
            "feedback": attempt.feedback,
        }
        for attempt in attempts
    ]