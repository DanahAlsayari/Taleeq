from datetime import datetime

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
)

import json

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from application_layer.assessment_analysis.assessment_analysis_service import (
    AssessmentAnalysisService,
)

from application_layer.authentication_managment import auth

from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
)

from data_and_integration_layer.database.connection import get_db

from data_and_integration_layer.database.models.pre_assessment import (
    PreAssessmentSubmission,
    AssessmentQuestion,
)

from data_and_integration_layer.database.models.assessment import (
    Assessment,
    AssessmentTask,
    SpeechTask,
)

from data_and_integration_layer.database.models.user import User

from data_and_integration_layer.database.Repositories.assessment_repository import (
    AssessmentRepository,
)

# =========================================================
# Schemas
# =========================================================


class PreAssessmentAnswer(BaseModel):
    question_id: int
    selected_options: list[str] = Field(
        min_length=1,
    )


class AssessmentTaskCreate(BaseModel):
    assessment_id: int
    task_type: str
    storage_url: str


class PreAssessmentSubmissionCreate(BaseModel):
    answers: list[PreAssessmentAnswer] = Field(
        min_length=6,
        max_length=6,
    )


# =========================================================
# Router
# =========================================================

router = APIRouter(
    prefix="/assessments",
    tags=["Assessment"],
)


# =========================================================
# Analyze Assessment
# =========================================================


@router.post("/{assessment_id}/analyze")
def analyze_assessment(
    assessment_id: int,
    db: Session = Depends(get_db),
):
    service = AssessmentAnalysisService(db)

    result = service.analyze_assessment(
        assessment_id,
    )

    return result


# =========================================================
# Test Audio Analysis
# =========================================================


@router.post("/test-analyze")
async def test_analyze_audio(
    file: UploadFile = File(...),
):
    audio_bytes = await file.read()

    print(
        "🎵 TEST FIRST 20 BYTES:",
        audio_bytes[:20],
    )

    print(
        "🎵 TEST AUDIO SIZE:",
        len(audio_bytes),
    )

    audio_format = file.filename.rsplit(".", 1)[-1].lower()

    analyzer = OpenAIAudioAnalyzer()

    result = analyzer.analyze_audio(
        audio_bytes,
        audio_format,
    )

    return result


# =========================================================
# Pre-Assessment Questions
# =========================================================


@router.get("/pre-assessment/questions")
def get_pre_assessment_questions(db: Session = Depends(get_db)):
    questions = (
        db.query(AssessmentQuestion).order_by(AssessmentQuestion.sort_order).all()
    )

    return {
        "questions": [
            {
                "id": question.id,
                "question": question.question,
                "subtitle": question.subtitle,
                "multiple": question.multiple,
                "options": question.options,
            }
            for question in questions
        ]
    }


@router.get("/speech/tasks")
def get_speech_tasks(
    db: Session = Depends(get_db),
):

    tasks = db.query(SpeechTask).order_by(SpeechTask.sort_order).all()

    return {
        "tasks": [
            {
                "id": task.id,
                "category": task.category,
                "instruction": task.instruction,
                "type": task.type,
                "content": task.content,
            }
            for task in tasks
        ]
    }


# =========================================================
# Submit Pre-Assessment
# =========================================================


@router.post(
    "/pre-assessment/submissions",
    status_code=201,
)
def submit_pre_assessment(
    data: PreAssessmentSubmissionCreate,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    question_ids = [answer.question_id for answer in data.answers]

    valid_question_ids = sorted(row.id for row in db.query(AssessmentQuestion).all())

    if sorted(question_ids) != (valid_question_ids):
        raise HTTPException(
            status_code=400,
            detail="All six questions must be answered once",
        )

    submission = PreAssessmentSubmission(
        user_id=current_user.id,
        answers=[answer.model_dump() for answer in data.answers],
    )

    db.add(submission)
    db.commit()
    db.refresh(submission)

    return {
        "message": "Pre-assessment submitted successfully",
        "submission_id": submission.id,
        "submitted_at": submission.submitted_at,
    }


# =========================================================
# Get Fluency Profile


# =========================================================


def build_task_results(tasks):
    task_results = []

    for task in tasks:
        result = task.analysis_result

        if result is None:
            continue

        patterns = {
            "repetition": result.repetition_percent or 0,
            "prolongation": result.prolongation_percent or 0,
            "block": result.block_percent or 0,
        }

        primary_pattern = max(patterns, key=patterns.get)

        task_results.append(
            {
                "task_type": task.task_type,
                "pattern": primary_pattern,
                "percent": patterns[primary_pattern],
                "stuttering_percent": result.stuttering_percent,
                "repetition_percent": result.repetition_percent,
                "prolongation_percent": result.prolongation_percent,
                "block_percent": result.block_percent,
            }
        )

    return task_results


@router.get("/fluency-profile")
def get_fluency_profile(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)

    profile = repository.get_fluency_profile(current_user.id)

    if not profile:
        raise HTTPException(
            status_code=404,
            detail="Fluency profile not found",
        )

    latest_assessment = (
        db.query(Assessment)
        .filter(Assessment.user_id == current_user.id)
        .order_by(Assessment.created_at.desc())
        .first()
    )

    task_results = []

    if latest_assessment:
        for task in latest_assessment.tasks:
            result = task.analysis_result

            if result is None:
                continue

            patterns = {
                "repetition": result.repetition_percent,
                "prolongation": result.prolongation_percent,
                "block": result.block_percent,
            }

            primary_pattern = max(patterns, key=patterns.get)

            task_results.append({
                "task_type": task.task_type,
                "pattern": primary_pattern,
                "percent": patterns[primary_pattern],
                "stuttering_percent": result.stuttering_percent,
                "repetition_percent": result.repetition_percent,
                "prolongation_percent": result.prolongation_percent,
                "block_percent": result.block_percent,
                "speech_events": [
                    {
                        "word_or_sound": event.word_or_sound,
                    }
                    for event in (result.speech_events or [])
                    if event.word_or_sound
                    and event.word_or_sound.strip()
                ],
            })
            task_order = {
                "task_1": 0,
                "task_2": 1,
                "task_3": 2,
            }

            task_results.sort(
                key=lambda item: task_order.get(
                    item["task_type"],
                    999,
                )
            )

    return {
        "overall_stuttering_percent": profile.overall_stuttering_percent,
        "primary_pattern": profile.primary_pattern,
        "repetition_percent": profile.repetition_percent,
        "prolongation_percent": profile.prolongation_percent,
        "block_percent": profile.block_percent,
        "speaking_rate": profile.speaking_rate,
        "timing_pacing": profile.timing_pacing,
        "task_results": task_results,
    }


# =========================================================
# Get Latest Completed Assessment Status
# =========================================================

@router.get("/status/onboarding")
def get_onboarding_status(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    pre_assessment = (
        db.query(PreAssessmentSubmission)
        .filter(
            PreAssessmentSubmission.user_id == current_user.id,
        )
        .first()
    )

    speech_assessment = (
        db.query(Assessment)
        .filter(
            Assessment.user_id == current_user.id,
            Assessment.status.in_(["COMPLETED", "completed"]),
            Assessment.completed_at.isnot(None),
        )
        .first()
    )

    pre_completed = pre_assessment is not None
    speech_completed = speech_assessment is not None

    if not pre_completed:
        next_step = "pre_assessment"
    elif not speech_completed:
        next_step = "speech_assessment"
    else:
        next_step = "completed"

    return {
        "pre_assessment_completed": pre_completed,
        "speech_assessment_completed": speech_completed,
        "next_step": next_step,
    }
@router.get("/status/latest")
def get_latest_assessment_status(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    assessment = (
        db.query(Assessment)
        .filter(
            Assessment.user_id == current_user.id,
            Assessment.status == "COMPLETED",
            Assessment.completed_at.isnot(None),
        )
        .order_by(Assessment.completed_at.desc())
        .first()
    )

    if not assessment:
        return {
            "has_assessment": False,
            "completed_at": None,
        }

    return {
        "has_assessment": True,
        "completed_at": assessment.completed_at,
    }


@router.get("/history")
def get_assessment_history(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)
    assessments = repository.get_assessment_history(current_user.id)
    results = []

    for assessment in assessments:
        results.append(
            {
                "assessment_id": assessment.id,
                "completed_at": assessment.completed_at,
                "overall_stuttering_percent": assessment.overall_stuttering_percent,
            }
        )

    return results


@router.get("/{assessment_id}/details")
def get_assessment_details(
    assessment_id: int,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)

    assessment = repository.get_assessment(assessment_id)

    if assessment is None:
        raise HTTPException(status_code=404, detail="Assessment not found")

    if assessment.user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="You are not allowed to access this assessment"
        )
    if assessment.status != "COMPLETED":
        raise HTTPException(status_code=400, detail="Assessment is not completed")

    tasks = repository.get_assessment_tasks(assessment_id)
    task_results = build_task_results(tasks)

    if not task_results:
        raise HTTPException(status_code=404, detail="Assessment results not found")

    count = len(task_results)

    repetition_percent = (
        sum(task["repetition_percent"] for task in task_results) / count
    )

    prolongation_percent = (
        sum(task["prolongation_percent"] for task in task_results) / count
    )

    block_percent = sum(task["block_percent"] for task in task_results) / count

    overall_patterns = {
        "repetition": repetition_percent,
        "prolongation": prolongation_percent,
        "block": block_percent,
    }

    if max(overall_patterns.values()) == 0:
        primary_pattern = "none"
    else:
        primary_pattern = max(overall_patterns, key=overall_patterns.get)

    return {
        "assessment_id": assessment.id,
        "completed_at": assessment.completed_at,
        "overall_stuttering_percent": assessment.overall_stuttering_percent,
        "primary_pattern": primary_pattern,
        "repetition_percent": repetition_percent,
        "prolongation_percent": prolongation_percent,
        "block_percent": block_percent,
        "speaking_rate": assessment.speaking_rate,
        "timing_pacing": assessment.timing_pacing,
        "task_results": task_results,
    }


# =========================================================
# Get Assessment Task Results
# =========================================================


@router.get("/{assessment_id}/task-results")
def get_task_results(
    assessment_id: int,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)

    assessment = repository.get_assessment(assessment_id)

    if not assessment:
        return {"message": "Assessment not found"}

    if assessment.user_id != current_user.id:
        return {"message": "Unauthorized"}

    tasks = repository.get_assessment_tasks(assessment_id)

    results = []

    for task in tasks:
        analysis = task.analysis_result

        if not analysis:
            continue

        patterns = {
            "repetition": analysis.repetition_percent,
            "prolongation": analysis.prolongation_percent,
            "block": analysis.block_percent,
        }

        highest_pattern = max(
            patterns,
            key=patterns.get,
        )

        results.append(
            {
                "task_id": task.id,
                "task_type": task.task_type,
                "highest_pattern": highest_pattern,
                "highest_pattern_percent": patterns[highest_pattern],
            }
        )

    return results


# =========================================================
# Create Assessment
# =========================================================


@router.post("/create")
def create_assessment(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    assessment = Assessment(
        user_id=current_user.id,
        status="PENDING",
    )

    db.add(assessment)
    db.commit()
    db.refresh(assessment)

    return {
        "assessment_id": assessment.id,
        "status": assessment.status,
    }


# =========================================================
# Create / Update Assessment Task
# =========================================================


@router.post("/tasks")
def create_assessment_task(
    data: AssessmentTaskCreate,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)

    assessment = repository.get_assessment(data.assessment_id)

    if not assessment:
        raise HTTPException(
            status_code=404,
            detail="Assessment not found",
        )

    if assessment.user_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Unauthorized",
        )

    # Check if this task already exists
    task = (
        db.query(AssessmentTask)
        .filter(
            AssessmentTask.assessment_id == data.assessment_id,
            AssessmentTask.task_type == data.task_type,
        )
        .first()
    )

    if task:
        # Update existing task instead of creating duplicate
        task.storage_url = data.storage_url
        task.status = "PENDING"
        task.error_message = None
        task.analyzed_at = None

    else:
        # Create a new task
        task = AssessmentTask(
            assessment_id=data.assessment_id,
            task_type=data.task_type,
            storage_url=data.storage_url,
            status="PENDING",
        )

        db.add(task)

    db.commit()
    db.refresh(task)

    return {
        "task_id": task.id,
        "assessment_id": task.assessment_id,
        "task_type": task.task_type,
        "storage_url": task.storage_url,
        "status": task.status,
    }


# =========================================================
# Analyze Assessment Audio Directly
# =========================================================


@router.post("/{assessment_id}/analyze-audio")
async def analyze_assessment_audio(
    assessment_id: int,
    files: list[UploadFile] = File(...),
    task_types: str = Form(...),
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)

    assessment = repository.get_assessment(assessment_id)

    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found")

    if assessment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Unauthorized")

    print("📝 RAW TASK TYPES:", repr(task_types))
    print("📝 TASK TYPES TYPE:", type(task_types))

    try:
        task_types = json.loads(task_types)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid task types.")

    if len(files) != len(task_types):
        raise HTTPException(
            status_code=400, detail="Each audio file must have a task type."
        )

    audio_tasks = []

    for file, task_type in zip(files, task_types):
        audio_bytes = await file.read()

        if not audio_bytes:
            raise HTTPException(
                status_code=400, detail=f"Empty audio file: {file.filename}"
            )

        audio_format = file.filename.rsplit(".", 1)[-1].lower()

        supported_formats = {
            "wav",
            "mp3",
            "m4a",
            "webm",
        }

        if audio_format not in supported_formats:
            raise HTTPException(
                status_code=400, detail=f"Unsupported audio format: {audio_format}"
            )

        print(
            f"🎙️ RECEIVED {file.filename} "
            f"| TASK: {task_type} "
            f"| SIZE: {len(audio_bytes)} "
            f"| FORMAT: {audio_format}"
        )

        audio_tasks.append(
            (
                task_type,
                audio_bytes,
                audio_format,
            )
        )

    service = AssessmentAnalysisService(db)

    try:
        result = service.analyze_audio_tasks(
            assessment_id=assessment_id,
            audio_tasks=audio_tasks,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    # Mark the assessment as completed only after
    # all audio tasks are analyzed successfully.
    assessment.status = "COMPLETED"
    assessment.completed_at = datetime.utcnow()

    db.commit()
    db.refresh(assessment)

    return {
        "assessment_id": assessment_id,
        "result": result,
    }


# =========================================================
# Analyze Latest Assessment
# =========================================================


@router.post("/analyze-latest")
def analyze_latest_assessment(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)

    assessment = repository.get_latest_assessment(current_user.id)

    if not assessment:
        raise HTTPException(
            status_code=404,
            detail="No assessment found",
        )

    service = AssessmentAnalysisService(db)

    try:
        result = service.analyze_assessment(assessment.id)

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        )

    return {
        "assessment_id": assessment.id,
        "result": result,
    }


# =========================================================
# Validate Single Assessment Audio
# =========================================================

@router.post("/{assessment_id}/validate-audio")
async def validate_assessment_audio(
    assessment_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)
    assessment = repository.get_assessment(assessment_id)

    if not assessment:
        raise HTTPException(
            status_code=404,
            detail="لم يتم العثور على التقييم.",
        )

    if assessment.user_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="غير مصرح لك بالوصول إلى هذا التقييم.",
        )

    audio_bytes = await file.read()

    if not audio_bytes:
        raise HTTPException(
            status_code=400,
            detail="التسجيل فارغ. أعيدي التسجيل وحاول مرة أخرى.",
        )

    try:
        analyzer = OpenAIAudioAnalyzer()

        # Validate audio only. Do not call OpenAI.
        analyzer._validate_audio(audio_bytes)

        return {
            "valid": True,
            "message": "التسجيل اجتاز التحقق الأولي.",
        }

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    except Exception as error:
        print(f"Audio validation failed: {error}")

        raise HTTPException(
            status_code=500,
            detail="تعذر التحقق من التسجيل حاليًا. حاول مرة أخرى.",
        ) from error