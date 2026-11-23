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

/// One point of the stuttering-percentage-per-session series.
class SessionStutteringPoint {
  const SessionStutteringPoint({
    required this.sessionId,
    required this.stutteringPercent,
    this.sequenceNumber,
    this.practiceDate,
  });

  final int sessionId;
  final int? sequenceNumber;
  final String? practiceDate;
  final double stutteringPercent;

  factory SessionStutteringPoint.fromJson(Map<String, dynamic> json) {
    return SessionStutteringPoint(
      sessionId: _asInt(json['session_id']),
      sequenceNumber: json['sequence_number'] is num
          ? _asInt(json['sequence_number'])
          : null,
      practiceDate: _asString(json['practice_date']),
      stutteringPercent: _asDouble(json['stuttering_percent']) ?? 0,
    );
  }
}

/// GET /practice-sessions/summary?period=week|month|all
class SessionProgressSummary {
  const SessionProgressSummary({
    required this.period,
    required this.completedSessions,
    required this.totalTrainingSeconds,
    this.latestScore,
    this.bestScore,
    this.stutteringChange,
    this.patternChanges,
    this.stutteringSeries = const [],
  });

  final String period;
  final int completedSessions;
  final int totalTrainingSeconds;
  final double? latestScore;
  final double? bestScore;

  /// Last session minus first session in the period (negative = better).
  final double? stutteringChange;

  /// repetition / prolongation / block: last session minus first session.
  final Map<String, double>? patternChanges;
  final List<SessionStutteringPoint> stutteringSeries;

  factory SessionProgressSummary.fromJson(Map<String, dynamic> json) {
    final series = json['stuttering_series'];

    return SessionProgressSummary(
      period: _asString(json['period']) ?? 'all',
      completedSessions: _asInt(json['completed_sessions']),
      totalTrainingSeconds: _asInt(json['total_training_seconds']),
      latestScore: _asDouble(json['latest_score']),
      bestScore: _asDouble(json['best_score']),
      stutteringChange: _asDouble(json['stuttering_change']),
      patternChanges: json['pattern_changes'] is Map
          ? {
              for (final entry in (json['pattern_changes'] as Map).entries)
                entry.key.toString(): _asDouble(entry.value) ?? 0,
            }
          : null,
      stutteringSeries: series is List
          ? series
                .whereType<Map>()
                .map(
                  (item) => SessionStutteringPoint.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

/// One point of the overview chart: a day and the stuttering % on it.
class OverviewPoint {
  const OverviewPoint({required this.date, required this.stutteringPercent});

  final DateTime date;
  final double stutteringPercent;

  static OverviewPoint? tryParse(Map<String, dynamic> json) {
    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    final percent = _asDouble(json['stuttering_percent']);

    if (date == null || percent == null) {
      return null;
    }

    return OverviewPoint(date: date, stutteringPercent: percent);
  }
}

/// First and last stuttering % of one exercise type, scenario or game.
class OverviewTypeResult {
  const OverviewTypeResult({
    required this.name,
    required this.attempts,
    required this.firstPercent,
    required this.lastPercent,
  });

  final String name;
  final int attempts;
  final double firstPercent;
  final double lastPercent;

  /// Last minus first (negative = better).
  double get change => lastPercent - firstPercent;
}

/// GET /practice-sessions/overview
class ProgressOverviewData {
  const ProgressOverviewData({
    this.sessionsSeries = const [],
    this.sessionsPatternChanges,
    this.trainingSeries = const [],
    this.trainingAttempts = const [],
    this.trainingPatternChanges,
    this.types = const [],
  });

  final List<OverviewPoint> sessionsSeries;
  final Map<String, double>? sessionsPatternChanges;
  final List<OverviewPoint> trainingSeries;
  final List<OverviewPoint> trainingAttempts;
  final Map<String, double>? trainingPatternChanges;
  final List<OverviewTypeResult> types;

  static List<OverviewPoint> _points(dynamic raw) {
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((item) => OverviewPoint.tryParse(Map<String, dynamic>.from(item)))
        .whereType<OverviewPoint>()
        .toList();
  }

  static Map<String, double>? _changes(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    return {
      for (final entry in raw.entries)
        entry.key.toString(): _asDouble(entry.value) ?? 0,
    };
  }

  factory ProgressOverviewData.fromJson(Map<String, dynamic> json) {
    final types = json['types'];

    return ProgressOverviewData(
      sessionsSeries: _points(json['sessions_series']),
      sessionsPatternChanges: _changes(json['sessions_pattern_changes']),
      trainingSeries: _points(json['training_series']),
      trainingAttempts: _points(json['training_attempts']),
      trainingPatternChanges: _changes(json['training_pattern_changes']),
      types: types is List
          ? types
                .whereType<Map>()
                .map(
                  (item) => OverviewTypeResult(
                    name: item['name']?.toString() ?? '',
                    attempts: _asInt(item['attempts']),
                    firstPercent: _asDouble(item['first_percent']) ?? 0,
                    lastPercent: _asDouble(item['last_percent']) ?? 0,
                  ),
                )
                .where((item) => item.name.isNotEmpty)
                .toList()
          : const [],
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
