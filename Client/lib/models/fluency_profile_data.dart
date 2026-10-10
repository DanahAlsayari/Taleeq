class TaskResultData {
  final String taskType;
  final String pattern;
  final double percent;

  const TaskResultData({
    required this.taskType,
    required this.pattern,
    required this.percent,
  });

  factory TaskResultData.fromJson(Map<String, dynamic> json) {
    return TaskResultData(
      taskType: (json['task_type'] as String?) ?? '',
      pattern: (json['pattern'] as String?) ?? '',
      percent: FluencyProfileData._toDouble(json['percent']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_type': taskType,
      'pattern': pattern,
      'percent': percent,
    };
  }
}

class FluencyProfileData {
  final double overallStutteringPercent;
  final String primaryPattern;
  final double repetitionPercent;
  final double prolongationPercent;
  final double blockPercent;
  final double speakingRate;
  final double timingPacing;

  final List<TaskResultData> taskResults;

  const FluencyProfileData({
    required this.overallStutteringPercent,
    required this.primaryPattern,
    required this.repetitionPercent,
    required this.prolongationPercent,
    required this.blockPercent,
    required this.speakingRate,
    required this.timingPacing,
    required this.taskResults,
  });

  factory FluencyProfileData.fromJson(Map<String, dynamic> json) {
    return FluencyProfileData(
      overallStutteringPercent:
          _toDouble(json['overall_stuttering_percent']),
      primaryPattern:
          (json['primary_pattern'] as String?) ?? 'Repetition',
      repetitionPercent:
          _toDouble(json['repetition_percent']),
      prolongationPercent:
          _toDouble(json['prolongation_percent']),
      blockPercent:
          _toDouble(json['block_percent']),
      speakingRate:
          _toDouble(json['speaking_rate']),
      timingPacing:
          _toDouble(json['timing_pacing']),
      taskResults:
          (json['task_results'] as List<dynamic>? ?? [])
              .map(
                (item) => TaskResultData.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall_stuttering_percent': overallStutteringPercent,
      'primary_pattern': primaryPattern,
      'repetition_percent': repetitionPercent,
      'prolongation_percent': prolongationPercent,
      'block_percent': blockPercent,
      'speaking_rate': speakingRate,
      'timing_pacing': timingPacing,
      'task_results':
          taskResults.map((task) => task.toJson()).toList(),
    };
  }

  factory FluencyProfileData.mock() {
    return const FluencyProfileData(
      overallStutteringPercent: 24.0,
      primaryPattern: 'Repetition',
      repetitionPercent: 15.0,
      prolongationPercent: 6.0,
      blockPercent: 3.0,
      speakingRate: 85.0,
      timingPacing: 72.0,
      taskResults: [],
    );
  }

  String get primaryPatternArabic {
    switch (primaryPattern.toLowerCase().trim()) {
      case 'repetition':
        return 'التكرار';
      case 'prolongation':
        return 'الإطالة';
      case 'block':
        return 'التوقف';
      default:
        return primaryPattern;
    }
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}