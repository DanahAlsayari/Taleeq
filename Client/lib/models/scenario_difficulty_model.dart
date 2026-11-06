class ScenarioDifficultyModel {
  final String id;
  final String scenarioId;
  final String difficulty;
  final bool isActive;

  ScenarioDifficultyModel({
    required this.id,
    required this.scenarioId,
    required this.difficulty,
    required this.isActive,
  });

  factory ScenarioDifficultyModel.fromJson(Map<String, dynamic> json) {
    return ScenarioDifficultyModel(
      id: json['id'].toString(),
      scenarioId: json['scenario_id'].toString(),
      difficulty: json['difficulty'] ?? '',
      isActive: json['is_active'] ?? false,
    );
  }
}