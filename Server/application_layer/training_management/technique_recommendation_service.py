from sqlalchemy.orm import Session

from data_and_integration_layer.database.Repositories.technique_repository import (
    TechniqueRepository,
)
from data_and_integration_layer.database.Repositories.training_goal_repository import (
    TrainingGoalRepository,
)

from data_and_integration_layer.ai_integration.goal_classifier import (
    GoalClassifier,
)

GOAL_TECHNIQUE_MAPPING = {
    "GENERAL_FLUENCY": [
        "Easy Onset",
        "Prolonged Speech",
        "Rate Control",
    ],
    "SPEECH_BLOCKS": [
        "Easy Onset",
        "Stuttering Modification / Easing",
    ],
    "SPEECH_REPETITIONS": [
        "Rate Control",
        "Prolonged Speech",
    ],
    "SPEECH_PROLONGATIONS": [
        "Stuttering Modification / Easing",
    ],
}
DEFAULT_TECHNIQUE_ORDER = [
    "Easy Onset",
    "Prolonged Speech",
    "Rate Control",
    "Controlled Pausing",
    "Metronome / Rhythmic Speech",
    "Cancellation",
    "Stuttering Modification / Easing",
]


class TechniqueRecommendationService:

    def __init__(self, db: Session):
        self.technique_repository = TechniqueRepository(db)
        self.goal_repository = TrainingGoalRepository(db)
        self.goal_classifier = GoalClassifier()

    # Retrieve the patient's active training goals and available techniques.
    def get_recommendation_inputs(self, user_id: int):
        active_goals = self.goal_repository.get_active_goals(user_id)
        techniques = self.technique_repository.get_all_techniques()

        return active_goals, techniques

    def classify_active_goals(self, active_goals) -> list[str]:
        categories = []

        for goal in active_goals:
            result = self.goal_classifier.classify_goal(goal.goal)
            categories.extend(result.categories)

        return categories

    def calculate_goal_scores(
        self,
        categories: list[str],
        techniques: list,
    ) -> dict[int, int]:

        scores = {technique.id: 0 for technique in techniques}

        for category in set(categories):
            matched_names = GOAL_TECHNIQUE_MAPPING.get(category, [])

            for technique in techniques:
                if technique.name_en in matched_names:
                    scores[technique.id] += 1

        return scores

    def get_goal_based_scores(self, user_id: int) -> dict[int, int]:

        active_goals, techniques = self.get_recommendation_inputs(user_id)

        categories = self.classify_active_goals(active_goals)

        scores = self.calculate_goal_scores(categories, techniques)

        return scores

    def rank_techniques(self, techniques, scores):
        return sorted(
            techniques,
            key=lambda technique: (
                -scores.get(technique.id, 0),
                technique.id,
            ),
        )

    def rank_goal_matched_by_rotation(
        self,
        techniques,
        scores,
        completed_session_counts,
    ):
        goal_matched = [
            technique for technique in techniques if scores.get(technique.id, 0) > 0
        ]
        return sorted(
            goal_matched,
            key=lambda technique: (
                completed_session_counts.get(technique.id, 0),
                -scores.get(technique.id, 0),
                technique.id,
            ),
        )

    def is_initial_practice_complete(
        self,
        scores,
        completed_session_counts,
    ) -> bool:

        matched_ids = [
            technique_id for technique_id, score in scores.items() if score > 0
        ]

        if not matched_ids:
            return False

        return all(
            completed_session_counts.get(technique_id, 0) >= 2
            for technique_id in matched_ids
        )

    def should_explore(self, sessions_since_initial_phase: int) -> bool:
        return (
            sessions_since_initial_phase > 0 and sessions_since_initial_phase % 3 == 0
        )

    def rank_exploration_techniques(
        self,
        techniques,
        scores,
        completed_session_counts,
    ):
        exploration_candidates = [
            technique for technique in techniques if scores.get(technique.id, 0) == 0
        ]

        return sorted(
            exploration_candidates,
            key=lambda technique: (
                completed_session_counts.get(technique.id, 0),
                technique.id,
            ),
        )

    def get_session_technique_candidates(
        self,
        techniques,
        scores,
        completed_session_counts,
        sessions_since_initial_phase,
    ):
        initial_complete = self.is_initial_practice_complete(
            scores,
            completed_session_counts,
        )
        explore = initial_complete and self.should_explore(sessions_since_initial_phase)
        goal_ranked = self.rank_goal_matched_by_rotation(
            techniques,
            scores,
            completed_session_counts,
        )
        if not goal_ranked:
            goal_ranked = sorted(
                techniques,
                key=lambda technique: (
                    completed_session_counts.get(technique.id, 0),
                    (
                        DEFAULT_TECHNIQUE_ORDER.index(technique.name_en)
                        if technique.name_en in DEFAULT_TECHNIQUE_ORDER
                        else len(DEFAULT_TECHNIQUE_ORDER)
                    ),
                    technique.id,
                ),
            )

        exploration_ranked = []

        if explore:
            exploration_ranked = self.rank_exploration_techniques(
                techniques,
                scores,
                completed_session_counts,
            )
        return {
            "goal_ranked": goal_ranked,
            "exploration_ranked": exploration_ranked,
            "explore": explore,
        }

    def select_session_techniques(
        self,
        candidates,
        exercise_count: int,
    ):
        if exercise_count <= 0:
            return []

        goal_ranked = candidates["goal_ranked"]
        selected = goal_ranked[:exercise_count]

        exploration_ranked = candidates["exploration_ranked"]

        if (
            candidates["explore"]
            and exploration_ranked
            and selected
            and exercise_count > 1
        ):
            selected = selected[: exercise_count - 1]
            selected.append(exploration_ranked[0])

        if selected and len(selected) < exercise_count:
            available = [
                technique
                for technique in selected
                if technique not in exploration_ranked
            ]

            index = 0

            while available and len(selected) < exercise_count:
                selected.append(available[index % len(available)])
                index += 1

        if len(selected) != exercise_count:
            raise ValueError("Unable to assign a technique to every exercise.")

        return selected
