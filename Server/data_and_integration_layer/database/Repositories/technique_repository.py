from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.technique import Technique


class TechniqueRepository:

    def __init__(self, db: Session):
        self.db = db

    def get_all_techniques(self) -> list[Technique]:
        return (
            self.db.query(Technique)
            .order_by(Technique.id)
            .all()
        )

    def get_technique_by_id(
        self,
        technique_id: int,
    ) -> Technique | None:

        return (
            self.db.query(Technique)
            .filter(Technique.id == technique_id)
            .first()
        )