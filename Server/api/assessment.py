from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from fastapi import APIRouter, Depends, File, UploadFile
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