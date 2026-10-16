class SpeechEventData {
  final String wordOrSound;

  const SpeechEventData({required this.wordOrSound});

  factory SpeechEventData.fromJson(Map<String, dynamic> json) {
    return SpeechEventData(
      wordOrSound: (json['word_or_sound'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'word_or_sound': wordOrSound};
  }
}

class TaskResultData {
  final String taskType;
  final String pattern;
  final double percent;
  final List<String> speechEvents;

  const TaskResultData({
    required this.taskType,
    required this.pattern,
    required this.percent,
    this.speechEvents = const [],
  });

  factory TaskResultData.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['speech_events'];

    final List<String> parsedEvents = rawEvents is List
        ? rawEvents
              .map((event) {
                if (event is String) {
                  return event.trim();
                }

                if (event is Map) {
                  return (event['word_or_sound'] ?? '').toString().trim();
                }

                return '';
              })
              .where((word) => word.isNotEmpty)
              .toList()
        : <String>[];

    return TaskResultData(
      taskType: (json['task_type'] ?? '').toString(),
      pattern: (json['pattern'] ?? '').toString(),
      percent: FluencyProfileData._toDouble(json['percent']),
      speechEvents: parsedEvents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_type': taskType,
      'pattern': pattern,
      'percent': percent,
      'speech_events': speechEvents
          .map((word) => {'word_or_sound': word})
          .toList(),
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
  final List<SpeechEventData> speechEvents;
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
    this.speechEvents = const [],
  });

  factory FluencyProfileData.fromJson(Map<String, dynamic> json) {
    final rawTaskResults = json['task_results'];
    final rawSpeechEvents = json['speech_events'];

    return FluencyProfileData(
      overallStutteringPercent: _toDouble(json['overall_stuttering_percent']),
      primaryPattern: (json['primary_pattern'] ?? 'Repetition').toString(),
      repetitionPercent: _toDouble(json['repetition_percent']),
      prolongationPercent: _toDouble(json['prolongation_percent']),
      blockPercent: _toDouble(json['block_percent']),
      speakingRate: _toDouble(json['speaking_rate']),
      timingPacing: _toDouble(json['timing_pacing']),
      taskResults: rawTaskResults is List
          ? rawTaskResults
                .whereType<Map>()
                .map(
                  (item) =>
                      TaskResultData.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <TaskResultData>[],
      speechEvents: rawSpeechEvents is List
          ? rawSpeechEvents
                .whereType<Map>()
                .map(
                  (event) => SpeechEventData.fromJson(
                    Map<String, dynamic>.from(event),
                  ),
                )
                .where((event) => event.wordOrSound.trim().isNotEmpty)
                .toList()
          : <SpeechEventData>[],
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
      'task_results': taskResults.map((task) => task.toJson()).toList(),
      'speech_events': speechEvents.map((event) => event.toJson()).toList(),
    };
  }

  String get primaryPatternArabic {
    switch (primaryPattern.toLowerCase().trim()) {
      case 'repetition':
        return 'التكرار';
      case 'prolongation':
        return 'الإطالة';
      case 'block':
        return 'التوقف';
      case 'none':
        return 'لا يوجد';
      default:
        return primaryPattern;
    }
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }
}
