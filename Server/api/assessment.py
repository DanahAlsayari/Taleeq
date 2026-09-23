from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.orm import Session

from application_layer.assessment_analysis.assessment_analysis_service import (
    AssessmentAnalysisService,
)
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.ai_integration.openai_audio import (
    OpenAIAudioAnalyzer,
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
        assessment_id
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
                "question": "متى بدأت التأتأة لديك ؟",
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
                "question": "كيف تصف بداية التأتأة لديك ؟",
                "subtitle": "اختر إجابة واحدة",
                "multiple": False,
                "options": [
                    "بدأت في الطفولة بشكل تدريجي",
                    "يوجد تاريخ عائلي للتأتأة",
                    "بدأت بشكل مفاجئ",
                    "بدأت بعد ضغط او تجربة نفسية صعبة",
                    "بدأت بعد إصابة أو حادث",
                    "بدأت بعد مشكلة صحية أو عصبية",
                    "بدأت بعد دواء أو علاج",
                    "لا أعرف أو لا أتذكر",
                ],
            },
            {
                "id": 3,
                "question": "هل سبق أن تلقيت جلسات علاج نطق/تخاطب للتأتأة ؟",
                "subtitle": "اختر إجابة واحدة",
                "multiple": False,
                "options": [
                    "نعم",
                    "لا",
                ],
            },
            {
                "id": 4,
                "question": "هل تتجنب أو تستبدل كلمات لأنك تتوقع انك ستتأتئ فيها ؟",
                "subtitle": "اختر إجابة واحدة",
                "multiple": False,
                "options": [
                    "غالبا",
                    "أحيانا",
                    "أبدا",
                ],
            },
            {
                "id": 5,
                "question": "في أي مواقف تزداد التأتأة لديك ؟",
                "subtitle": "اختر جميع الإجابات التي تنطبق عليك",
                "multiple": True,
                "options": [
                    "التحدث مع اشخاص جدد",
                    "المكالمات الهاتفية",
                    "العروض والتحدث أمام مجموعة",
                    "القراءة بصوت مرتفع",
                    "المحادثات اليومية",
                    "مواقف أخرى",
                ],
            },
            {
                "id": 6,
                "question": "ماذا تريد ان تحسن ؟",
                "subtitle": "اختر جميع الإجابات التي تنطبق عليك",
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