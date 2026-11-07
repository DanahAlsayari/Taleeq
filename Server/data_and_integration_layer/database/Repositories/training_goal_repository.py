from sqlalchemy.orm import Session

from data_and_integration_layer.database.models.training_goal import TrainingGoal


class TrainingGoalRepository:

    def __init__(self, db: Session):
        self.db = db

    def get_active_goals(self, user_id: int) -> list[TrainingGoal]:
        return (
            self.db.query(TrainingGoal)
            .filter(
                TrainingGoal.user_id == user_id,
                TrainingGoal.is_completed.is_(False),
            )
            .order_by(TrainingGoal.id)
            .all()
        )
