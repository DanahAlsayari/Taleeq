import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from data_and_integration_layer.database.connection import get_db
from application_layer.training_management.technique_service import (
    TechniqueService,
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/techniques",
    tags=["Techniques"],
)


@router.get("")
def get_all_techniques(db: Session = Depends(get_db)):
    logger.info("[TechniqueAPI] Fetching all techniques")

    service = TechniqueService(db)
    return service.get_all_techniques()


@router.get("/{technique_id}")
def get_technique(
    technique_id: int,
    db: Session = Depends(get_db),
):
    logger.info(
        "[TechniqueAPI] Requested technique_id=%s",
        technique_id,
    )

    service = TechniqueService(db)
    technique = service.get_technique(technique_id)

    if technique is None:
        logger.warning(
            "[TechniqueAPI] Technique not found: id=%s",
            technique_id,
        )
        raise HTTPException(
            status_code=404,
            detail="Technique not found",
        )

    return technique