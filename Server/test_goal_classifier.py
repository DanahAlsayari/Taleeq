from types import SimpleNamespace

from application_layer.training_management.technique_recommendation_service import (
    TechniqueRecommendationService,
)

techniques = [
    SimpleNamespace(id=1, name_en="Easy Onset"),
    SimpleNamespace(id=2, name_en="Prolonged Speech"),
    SimpleNamespace(id=3, name_en="Rate Control"),
    SimpleNamespace(id=4, name_en="Stuttering Modification / Easing"),
    SimpleNamespace(id=5, name_en="Cancellation"),
]

categories = ["GENERAL_FLUENCY", "SPEECH_BLOCKS"]

service = TechniqueRecommendationService.__new__(
    TechniqueRecommendationService
)

scores = service.calculate_goal_scores(categories, techniques)

print(scores)