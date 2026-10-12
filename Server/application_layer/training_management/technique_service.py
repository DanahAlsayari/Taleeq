import logging

from sqlalchemy.orm import Session

from data_and_integration_layer.database.Repositories.technique_repository import (
    TechniqueRepository,
)


logger = logging.getLogger(__name__)


class TechniqueService:

    def __init__(self, db: Session):
        self.repository = TechniqueRepository(db)

    def get_all_techniques(self):
        logger.info("Fetching all techniques")

        techniques = self.repository.get_all_techniques()

        logger.info(
            "Fetched %d techniques",
            len(techniques),
        )

        return techniques

    def get_technique(self, technique_id: int):
        logger.info(
            "Fetching technique_id=%s",
            technique_id,
        )

        technique = self.repository.get_technique_by_id(
            technique_id
        )

        if technique is None:
            logger.warning(
                "Technique not found: technique_id=%s",
                technique_id,
            )
        else:
            logger.info(
                "Technique found: technique_id=%s",
                technique_id,
            )

        return technique