from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from application_layer.authentication_managment.auth import get_current_user
from application_layer.training_management.scenario_analysis_service import (
    ScenarioAnalysisService,
)
from data_and_integration_layer.ai_integration.openai_audio import (
    UnusableSpeechError,
)
from data_and_integration_layer.database.connection import get_db
from data_and_integration_layer.database.models.user import User

router = APIRouter(prefix="/scenarios", tags=["Scenarios"])


@router.post("/attempts/{attempt_id}/analyze-audio")
async def analyze_scenario_audio(
    attempt_id: UUID,
    file: UploadFile = File(...),
    end_reason: str = Form("user_ended"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    audio_bytes = await file.read()

    if not audio_bytes:
        raise HTTPException(
            status_code=400,
            detail="التسجيل فارغ. أعيدي التسجيل.",
        )

    audio_format = (
        file.filename.rsplit(".", 1)[-1].lower()
        if file.filename and "." in file.filename
        else ""
    )

    if audio_format not in {"wav", "mp3", "m4a", "webm"}:
        raise HTTPException(
            status_code=400,
            detail="صيغة التسجيل غير مدعومة.",
        )

    service = ScenarioAnalysisService(db)

    try:
        return service.analyze_scenario(
            user_id=current_user.id,
            attempt_id=attempt_id,
            audio_bytes=audio_bytes,
            audio_format=audio_format,
            end_reason=end_reason,
        )
    except LookupError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except UnusableSpeechError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
