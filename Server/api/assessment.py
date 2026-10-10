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
    SpeechTask
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

    audio_format = (
        file.filename
        .rsplit(".", 1)[-1]
        .lower()
    )

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
        db.query(AssessmentQuestion)
        .order_by(AssessmentQuestion.sort_order)
        .all()
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

    # return {
    #     "questions": [
    #         {
    #             "id": 1,
    #             "question": "متى بدأت التأتأة لديك؟",
    #             "subtitle": "اختر إجابة واحدة",
    #             "multiple": False,
    #             "options": [
    #                 "منذ الطفولة",
    #                 "في مرحلة المراهقة",
    #                 "في مرحلة البلوغ",
    #                 "لست متأكدًا",
    #             ],
    #         },
    #         {
    #             "id": 2,
    #             "question": "كيف تصف بداية التأتأة لديك؟",
    #             "subtitle": "اختر إجابة واحدة",
    #             "multiple": False,
    #             "options": [
    #                 "بدأت في الطفولة بشكل تدريجي",
    #                 "يوجد تاريخ عائلي للتأتأة",
    #                 "بدأت بشكل مفاجئ",
    #                 "بدأت بعد ضغط أو تجربة نفسية صعبة",
    #                 "بدأت بعد إصابة أو حادث",
    #                 "بدأت بعد مشكلة صحية أو عصبية",
    #                 "بدأت بعد دواء أو علاج",
    #                 "لا أعرف أو لا أتذكر",
    #             ],
    #         },
    #         {
    #             "id": 3,
    #             "question": (
    #                 "هل سبق أن تلقيت جلسات علاج "
    #                 "نطق/تخاطب للتأتأة؟"
    #             ),
    #             "subtitle": "اختر إجابة واحدة",
    #             "multiple": False,
    #             "options": [
    #                 "نعم",
    #                 "لا",
    #             ],
    #         },
    #         {
    #             "id": 4,
    #             "question": (
    #                 "هل تتجنب أو تستبدل كلمات لأنك "
    #                 "تتوقع أنك ستتأتئ فيها؟"
    #             ),
    #             "subtitle": "اختر إجابة واحدة",
    #             "multiple": False,
    #             "options": [
    #                 "غالبًا",
    #                 "أحيانًا",
    #                 "أبدًا",
    #             ],
    #         },
    #         {
    #             "id": 5,
    #             "question": "في أي مواقف تزداد التأتأة لديك؟",
    #             "subtitle": (
    #                 "اختر جميع الإجابات التي تنطبق عليك"
    #             ),
    #             "multiple": True,
    #             "options": [
    #                 "التحدث مع أشخاص جدد",
    #                 "المكالمات الهاتفية",
    #                 "العروض والتحدث أمام مجموعة",
    #                 "القراءة بصوت مرتفع",
    #                 "المحادثات اليومية",
    #                 "مواقف أخرى",
    #             ],
    #         },
    #         {
    #             "id": 6,
    #             "question": "ماذا تريد أن تحسن؟",
    #             "subtitle": (
    #                 "اختر جميع الإجابات التي تنطبق عليك"
    #             ),
    #             "multiple": True,
    #             "options": [
    #                 "التحدث براحة أكبر",
    #                 "المحادثات اليومية",
    #                 "التقديم والعروض",
    #                 "المكالمات الهاتفية",
    #                 "مقابلات العمل",
    #                 "تقليل التوقف أثناء الكلام",
    #                 "تقليل الشد والتوتر أثناء الكلام",
    #             ],
    #         },
    #     ]
    # }


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
    question_ids = [
        answer.question_id
        for answer in data.answers
    ]

    valid_question_ids = sorted(
        row.id
        for row in db.query(AssessmentQuestion).all()
    )

    if sorted(question_ids) != (valid_question_ids):
        raise HTTPException(
            status_code=400,
            detail="All six questions must be answered once",
        )

    submission = PreAssessmentSubmission(
        user_id=current_user.id,
        answers=[
            answer.model_dump()
            for answer in data.answers
        ],
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

@router.get("/fluency-profile")
def get_fluency_profile(
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    repository = AssessmentRepository(db)

    profile = repository.get_fluency_profile(
        current_user.id
    )

    if not profile:
        raise HTTPException(
            status_code=404,
            detail="Fluency profile not found",
        )

    return {
        "overall_stuttering_percent":
            profile.overall_stuttering_percent,

        "primary_pattern":
            profile.primary_pattern,

        "repetition_percent":
            profile.repetition_percent,

        "prolongation_percent":
            profile.prolongation_percent,

        "block_percent":
            profile.block_percent,

        "speaking_rate":
            profile.speaking_rate,

        "timing_pacing":
            profile.timing_pacing,
    }


# =========================================================
# Get Latest Completed Assessment Status
# =========================================================

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

    assessment = repository.get_assessment(
        assessment_id
    )

    if not assessment:
        return {
            "message": "Assessment not found"
        }

    if assessment.user_id != current_user.id:
        return {
            "message": "Unauthorized"
        }

    tasks = repository.get_assessment_tasks(
        assessment_id
    )

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

        results.append({
            "task_id": task.id,
            "task_type": task.task_type,
            "highest_pattern": highest_pattern,
            "highest_pattern_percent":
                patterns[highest_pattern],
        })

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

    assessment = repository.get_assessment(
        data.assessment_id
    )

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
            AssessmentTask.assessment_id ==
            data.assessment_id,

            AssessmentTask.task_type ==
            data.task_type,
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
        raise HTTPException(
            status_code=404,
            detail="Assessment not found"
        )

    if assessment.user_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Unauthorized"
        )

    print("📝 RAW TASK TYPES:", repr(task_types))
    print("📝 TASK TYPES TYPE:", type(task_types))

    try:
        task_types = json.loads(task_types)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=400,
            detail="Invalid task types."
        )

    if len(files) != len(task_types):
        raise HTTPException(
            status_code=400,
            detail="Each audio file must have a task type."
        )

    audio_tasks = []

    for file, task_type in zip(files, task_types):
        audio_bytes = await file.read()

        if not audio_bytes:
            raise HTTPException(
                status_code=400,
                detail=f"Empty audio file: {file.filename}"
            )

        audio_format = (
            file.filename
            .rsplit(".", 1)[-1]
            .lower()
        )

        supported_formats = {
            "wav",
            "mp3",
            "m4a",
            "webm",
        }

        if audio_format not in supported_formats:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported audio format: {audio_format}"
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
        )

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

    assessment = repository.get_latest_assessment(
        current_user.id
    )

    if not assessment:
        raise HTTPException(
            status_code=404,
            detail="No assessment found",
        )

    service = AssessmentAnalysisService(db)

    try:
        result = service.analyze_assessment(
            assessment.id
        )

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        )

    return {
        "assessment_id": assessment.id,
        "result": result,
    }