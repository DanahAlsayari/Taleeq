from sqlalchemy.orm import Session, selectinload

from data_and_integration_layer.database.models.practice_session import (
    PracticeSession,
    PracticeSessionExercise,
)

from sqlalchemy import func


class PracticeSessionRepository:

    def __init__(self, db: Session):
        self.db = db

    def get_completed_session_counts(self, user_id: int) -> dict[int, int]:
        results = (
            self.db.query(
                PracticeSessionExercise.technique_id,
                func.count(func.distinct(PracticeSessionExercise.session_id)).label(
                    "session_count"
                ),
            )
            .join(
                PracticeSession,
                PracticeSessionExercise.session_id == PracticeSession.id,
            )
            .filter(
                PracticeSession.user_id == user_id,
                PracticeSessionExercise.status == "completed",
                PracticeSessionExercise.technique_id.isnot(None),
                PracticeSession.status == "completed",
            )
            .group_by(PracticeSessionExercise.technique_id)
            .all()
        )
        return {technique_id: session_count for technique_id, session_count in results}

    def get_completed_sessions(self, user_id: int):
        return (
            self.db.query(PracticeSession)
            .options(selectinload(PracticeSession.exercises))
            .filter(
                PracticeSession.user_id == user_id,
                PracticeSession.status == "completed",
            )
            .order_by(
                PracticeSession.completed_at.asc(),
                PracticeSession.id.asc(),
            )
            .all()
        )
    def get_completed_exercises(self, user_id: int):
        return (
            self.db.query(PracticeSessionExercise)
            .join(
                PracticeSession,
                PracticeSessionExercise.session_id == PracticeSession.id,
            )
            .filter(
                PracticeSession.user_id == user_id,
                PracticeSessionExercise.status == "completed",
                PracticeSessionExercise.technique_id.isnot(None),
                PracticeSessionExercise.completed_at.isnot(None),
                PracticeSession.status == "completed",
            )
            .order_by(
                PracticeSessionExercise.completed_at.asc(),
                PracticeSessionExercise.id.asc(),
            )
            .all()
        )
