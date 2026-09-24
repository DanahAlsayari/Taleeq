from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
)

from data_and_integration_layer.database.Repositories.assessment_repository import (
    AssessmentRepository,
)

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
)
from data_and_integration_layer.database.models.user import User


class PreAssessmentAnswer(BaseModel):
    question_id: int
    selected_options: list[str] = Field(
        min_length=1,
    )


class PreAssessmentSubmissionCreate(BaseModel):
    answers: list[PreAssessmentAnswer] = Field(
        min_length=6,
        max_length=6,
    )


router = APIRouter(
    prefix="/assessments",
    tags=["Assessment"],
)


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


@router.post("/test-analyze")
async def test_analyze_audio(
    file: UploadFile = File(...),
):
    audio_bytes = await file.read()

    audio_format = file.filename.rsplit(".", 1)[-1].lower()

    analyzer = OpenAIAudioAnalyzer()

    result = analyzer.analyze_audio(
        audio_bytes,
        audio_format,
    )

    return result


@router.get("/pre-assessment/questions")
def get_pre_assessment_questions():
    return {
        "questions": [
            {
                "id": 1,
                "question": "متى بدأت التأتأة لديك؟",
                "subtitle": "اختر إجابة واحدة",
                "multiple": False,
                "options": [
                    "منذ الطفولة",
                    "في مرحلة المراهقة",
                    "في مرحلة البلوغ",
                    "لست متأكدًا",
                ],
            },
            {
                "id": 2,
                "question": "كيف تصف بداية التأتأة لديك؟",
                "subtitle": "اختر إجابة واحدة",
                "multiple": False,
                "options": [
                    "بدأت في الطفولة بشكل تدريجي",
                    "يوجد تاريخ عائلي للتأتأة",
                    "بدأت بشكل مفاجئ",
                    "بدأت بعد ضغط أو تجربة نفسية صعبة",
                    "بدأت بعد إصابة أو حادث",
                    "بدأت بعد مشكلة صحية أو عصبية",
                    "بدأت بعد دواء أو علاج",
                    "لا أعرف أو لا أتذكر",
                ],
            },
            {
                "id": 3,
                "question": (
                    "هل سبق أن تلقيت جلسات علاج "
                    "نطق/تخاطب للتأتأة؟"
                ),
                "subtitle": "اختر إجابة واحدة",
                "multiple": False,
                "options": [
                    "نعم",
                    "لا",
                ],
            },
            {
                "id": 4,
                "question": (
                    "هل تتجنب أو تستبدل كلمات لأنك "
                    "تتوقع أنك ستتأتئ فيها؟"
                ),
                "subtitle": "اختر إجابة واحدة",
                "multiple": False,
                "options": [
                    "غالبًا",
                    "أحيانًا",
                    "أبدًا",
                ],
            },
            {
                "id": 5,
                "question": "في أي مواقف تزداد التأتأة لديك؟",
                "subtitle": (
                    "اختر جميع الإجابات التي تنطبق عليك"
                ),
                "multiple": True,
                "options": [
                    "التحدث مع أشخاص جدد",
                    "المكالمات الهاتفية",
                    "العروض والتحدث أمام مجموعة",
                    "القراءة بصوت مرتفع",
                    "المحادثات اليومية",
                    "مواقف أخرى",
                ],
            },
            {
                "id": 6,
                "question": "ماذا تريد أن تحسن؟",
                "subtitle": (
                    "اختر جميع الإجابات التي تنطبق عليك"
                ),
                "multiple": True,
                "options": [
                    "التحدث براحة أكبر",
                    "المحادثات اليومية",
                    "التقديم والعروض",
                    "المكالمات الهاتفية",
                    "مقابلات العمل",
                    "تقليل التوقف أثناء الكلام",
                    "تقليل الشد والتوتر أثناء الكلام",
                ],
            },
        ]
    }


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

    if sorted(question_ids) != [1, 2, 3, 4, 5, 6]:
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
        "overall_stuttering_percent": profile.overall_stuttering_percent,
        "primary_pattern": profile.primary_pattern,
        "repetition_percent": profile.repetition_percent,
        "prolongation_percent": profile.prolongation_percent,
        "block_percent": profile.block_percent,
        "speaking_rate": profile.speaking_rate,
        "timing_pacing": profile.timing_pacing,
    }


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

        results.append({
            "task_id": task.id,
            "task_type": task.task_type,
            "highest_pattern": highest_pattern,
            "highest_pattern_percent": patterns[highest_pattern],
        })

    return results
