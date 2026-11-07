class ScenarioAttemptModel {
  final String id;
  final int userId;
  final String scenarioId;
  final String scenarioDifficultyId;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final Map<String, dynamic>? analysisResult;
  final String? endReason;

  ScenarioAttemptModel({
    required this.id,
    required this.userId,
    required this.scenarioId,
    required this.scenarioDifficultyId,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.analysisResult,
    this.endReason,
  });

  factory ScenarioAttemptModel.fromJson(Map<String, dynamic> json) {
    return ScenarioAttemptModel(
      id: json['id'].toString(),
      userId: (json['user_id'] as num).toInt(),
      scenarioId: json['scenario_id'].toString(),
      scenarioDifficultyId: json['scenario_difficulty_id'].toString(),
      status: json['status'] ?? '',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'])
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      analysisResult: json['analysis_result'] is Map
          ? Map<String, dynamic>.from(json['analysis_result'])
          : null,
      endReason: json['end_reason'],
    );
  }
}