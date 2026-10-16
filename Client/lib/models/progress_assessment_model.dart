class ProgressAssessment {
  final int assessmentId;
  final DateTime completedAt;
  final double overallStutteringPercent;

  const ProgressAssessment({
    required this.assessmentId,
    required this.completedAt,
    required this.overallStutteringPercent,
  });

  factory ProgressAssessment.fromJson(Map<String, dynamic> json) {
    return ProgressAssessment(
      assessmentId: (json['assessment_id'] as num).toInt(),
      completedAt: DateTime.parse(json['completed_at'] as String),
      overallStutteringPercent: _toDouble(json['overall_stuttering_percent']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
