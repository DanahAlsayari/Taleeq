// Models for the post-session result screens.
// Every field is nullable-safe because results can be partial
// (for example an exercise without a technique).

double? _asDouble(dynamic value) => value is num ? value.toDouble() : null;

int _asInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

String? _asString(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> _asStringList(dynamic value) => value is List
    ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
    : <String>[];

class ResultScores {
  const ResultScores({
    this.total,
    this.fluency,
    this.rhythm,
    this.speedControl,
    this.taskAdherence,
  });

  final double? total;
  final double? fluency;
  final double? rhythm;
  final double? speedControl;
  final double? taskAdherence;

  factory ResultScores.fromJson(dynamic json) {
    final map = _asMap(json);

    return ResultScores(
      total: _asDouble(map['total_score']),
      fluency: _asDouble(map['fluency_score']),
      rhythm: _asDouble(map['rhythm_score']),
      speedControl: _asDouble(map['speed_control_score']),
      taskAdherence: _asDouble(map['task_adherence_score']),
    );
  }
}

class ResultMetrics {
  const ResultMetrics({
    this.stuttering,
    this.repetition,
    this.prolongation,
    this.block,
  });

  final double? stuttering;
  final double? repetition;
  final double? prolongation;
  final double? block;

  factory ResultMetrics.fromJson(dynamic json) {
    final map = _asMap(json);

    return ResultMetrics(
      stuttering: _asDouble(map['stuttering_percent']),
      repetition: _asDouble(map['repetition_percent']),
      prolongation: _asDouble(map['prolongation_percent']),
      block: _asDouble(map['block_percent']),
    );
  }
}

class SessionExerciseSummary {
  const SessionExerciseSummary({
    required this.sessionExerciseId,
    required this.position,
    required this.title,
    this.exerciseType,
    this.difficulty,
    this.status,
    this.techniqueName,
    this.techniqueStatus,
    this.totalScore,
  });

  final int sessionExerciseId;
  final int position;
  final String title;
  final String? exerciseType;
  final String? difficulty;
  final String? status;
  final String? techniqueName;

  /// applied | partial | not_applied | null
  final String? techniqueStatus;
  final double? totalScore;

  factory SessionExerciseSummary.fromJson(Map<String, dynamic> json) {
    return SessionExerciseSummary(
      sessionExerciseId: _asInt(json['session_exercise_id']),
      position: _asInt(json['position']),
      title: _asString(json['title']) ?? 'تمرين',
      exerciseType: _asString(json['exercise_type']),
      difficulty: _asString(json['difficulty']),
      status: _asString(json['status']),
      techniqueName: _asString(json['technique_name']),
      techniqueStatus: _asString(json['technique_status']),
      totalScore: _asDouble(json['total_score']),
    );
  }
}

class SessionResultData {
  const SessionResultData({
    required this.sessionId,
    required this.ready,
    required this.exerciseCount,
    required this.completedExerciseCount,
    required this.exercises,
    this.sequenceNumber,
    this.practiceDate,
    this.scores = const ResultScores(),
    this.metrics = const ResultMetrics(),
    this.strength,
    this.improvement,
    this.techniqueApplied = 0,
    this.techniquePartial = 0,
    this.techniqueNotApplied = 0,
    this.scoreChange,
  });

  final int sessionId;

  /// False while some exercises are still being analyzed.
  final bool ready;
  final int exerciseCount;
  final int completedExerciseCount;
  final List<SessionExerciseSummary> exercises;
  final int? sequenceNumber;
  final String? practiceDate;
  final ResultScores scores;
  final ResultMetrics metrics;
  final String? strength;
  final String? improvement;
  final int techniqueApplied;
  final int techniquePartial;
  final int techniqueNotApplied;
  final double? scoreChange;

  factory SessionResultData.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map ? _asMap(json['result']) : null;
    final feedback = _asMap(result?['feedback']);
    final techniqueSummary = _asMap(result?['technique_summary']);
    final comparison = _asMap(result?['comparison']);

    final exercises = (json['exercises'] is List)
        ? (json['exercises'] as List)
              .whereType<Map>()
              .map(
                (item) => SessionExerciseSummary.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <SessionExerciseSummary>[];

    exercises.sort((a, b) => a.position.compareTo(b.position));

    return SessionResultData(
      sessionId: _asInt(json['session_id']),
      ready: json['status'] == 'ready' && result != null,
      exerciseCount: _asInt(json['exercise_count'], exercises.length),
      completedExerciseCount: _asInt(json['completed_exercise_count']),
      exercises: exercises,
      sequenceNumber: json['sequence_number'] is num
          ? _asInt(json['sequence_number'])
          : null,
      practiceDate: _asString(json['practice_date']),
      scores: ResultScores.fromJson(result?['scores']),
      metrics: ResultMetrics.fromJson(result?['metrics']),
      strength: _asString(feedback['strength']),
      improvement: _asString(feedback['improvement']),
      techniqueApplied: _asInt(techniqueSummary['applied']),
      techniquePartial: _asInt(techniqueSummary['partial']),
      techniqueNotApplied: _asInt(techniqueSummary['not_applied']),
      scoreChange: _asDouble(comparison['score_change']),
    );
  }
}

class SessionHistoryItem {
  const SessionHistoryItem({
    required this.sessionId,
    required this.exerciseCount,
    this.sequenceNumber,
    this.practiceDate,
    this.totalScore,
    this.scoreChange,
  });

  final int sessionId;
  final int exerciseCount;
  final int? sequenceNumber;
  final String? practiceDate;
  final double? totalScore;
  final double? scoreChange;

  factory SessionHistoryItem.fromJson(Map<String, dynamic> json) {
    return SessionHistoryItem(
      sessionId: _asInt(json['session_id']),
      exerciseCount: _asInt(json['exercise_count']),
      sequenceNumber: json['sequence_number'] is num
          ? _asInt(json['sequence_number'])
          : null,
      practiceDate: _asString(json['practice_date']),
      totalScore: _asDouble(json['total_score']),
      scoreChange: _asDouble(json['score_change']),
    );
  }
}

class ExerciseTechniqueResult {
  const ExerciseTechniqueResult({
    this.nameAr,
    this.description,
    this.status,
    this.appliedWhere = const [],
    this.improveWhere = const [],
    this.tip,
  });

  final String? nameAr;
  final String? description;

  /// applied | partial | not_applied | null
  final String? status;
  final List<String> appliedWhere;
  final List<String> improveWhere;
  final String? tip;

  factory ExerciseTechniqueResult.fromJson(dynamic json) {
    final map = _asMap(json);

    return ExerciseTechniqueResult(
      nameAr: _asString(map['name_ar']),
      description: _asString(map['description']),
      status: _asString(map['status']),
      appliedWhere: _asStringList(map['applied_where']),
      improveWhere: _asStringList(map['improve_where']),
      tip: _asString(map['tip']),
    );
  }
}

class ExerciseResultData {
  const ExerciseResultData({
    required this.sessionExerciseId,
    required this.ready,
    required this.title,
    this.exerciseType,
    this.difficulty,
    this.scores = const ResultScores(),
    this.metrics = const ResultMetrics(),
    this.strength,
    this.improvement,
    this.technique,
    this.scoreChange,
  });

  final int sessionExerciseId;
  final bool ready;
  final String title;
  final String? exerciseType;
  final String? difficulty;
  final ResultScores scores;
  final ResultMetrics metrics;
  final String? strength;
  final String? improvement;
  final ExerciseTechniqueResult? technique;
  final double? scoreChange;

  factory ExerciseResultData.fromJson(Map<String, dynamic> json) {
    final exercise = _asMap(json['exercise']);
    final result = json['result'] is Map ? _asMap(json['result']) : null;
    final feedback = _asMap(result?['feedback']);
    final comparison = _asMap(result?['comparison']);

    return ExerciseResultData(
      sessionExerciseId: _asInt(json['session_exercise_id']),
      ready: json['status'] == 'ready' && result != null,
      title: _asString(exercise['title']) ?? 'تمرين',
      exerciseType: _asString(exercise['exercise_type']),
      difficulty: _asString(exercise['difficulty']),
      scores: ResultScores.fromJson(result?['scores']),
      metrics: ResultMetrics.fromJson(result?['metrics']),
      strength: _asString(feedback['strength']),
      improvement: _asString(feedback['improvement']),
      technique: result?['technique'] is Map
          ? ExerciseTechniqueResult.fromJson(result?['technique'])
          : null,
      scoreChange: _asDouble(comparison['score_change']),
    );
  }
}
