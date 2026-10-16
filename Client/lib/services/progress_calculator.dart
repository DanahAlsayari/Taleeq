import '../models/progress_assessment_model.dart';
import '../models/fluency_profile_data.dart';

class ProgressCalculator {
  static List<ProgressAssessment> sortChronologically(
    List<ProgressAssessment> assessments,
  ) {
    final sorted = List<ProgressAssessment>.from(assessments);

    sorted.sort((a, b) {
      final dateComparison = a.completedAt.compareTo(b.completedAt);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return a.assessmentId.compareTo(b.assessmentId);
    });

    return sorted;
  }

  static double calculateChange(double previous, double current) {
    return current - previous;
  }

  static ProgressAssessment? getLatestAssessment(
    List<ProgressAssessment> assessments,
  ) {
    if (assessments.isEmpty) {
      return null;
    }

    final sorted = sortChronologically(assessments);

    return sorted.last;
  }

  static ProgressAssessment? getFirstAssessment(
    List<ProgressAssessment> assessments,
  ) {
    if (assessments.isEmpty) {
      return null;
    }

    final sorted = sortChronologically(assessments);

    return sorted.first;
  }

  static ProgressAssessment? getPreviousAssessment(
    List<ProgressAssessment> assessments,
  ) {
    if (assessments.length < 2) {
      return null;
    }

    final sorted = sortChronologically(assessments);

    return sorted[sorted.length - 2];
  }

  static double? getOverallChangeFromFirst(
    List<ProgressAssessment> assessments,
  ) {
    if (assessments.length < 2) {
      return null;
    }

    final first = getFirstAssessment(assessments)!;
    final latest = getLatestAssessment(assessments)!;

    return calculateChange(
      first.overallStutteringPercent,
      latest.overallStutteringPercent,
    );
  }

  static double? getOverallChangeFromPrevious(
    List<ProgressAssessment> assessments,
  ) {
    if (assessments.length < 2) {
      return null;
    }

    final previous = getPreviousAssessment(assessments)!;
    final latest = getLatestAssessment(assessments)!;

    return calculateChange(
      previous.overallStutteringPercent,
      latest.overallStutteringPercent,
    );
  }

  static List<ProgressAssessment> getOverallTrend(
    List<ProgressAssessment> assessments,
  ) {
    return sortChronologically(assessments);
  }

  static List<AssessmentProgressData> sortDetailedChronologically(
    List<AssessmentProgressData> assessments,
  ) {
    final sorted = List<AssessmentProgressData>.from(assessments);

    sorted.sort((a, b) {
      final dateComparison = a.assessment.completedAt.compareTo(
        b.assessment.completedAt,
      );

      if (dateComparison != 0) {
        return dateComparison;
      }

      return a.assessment.assessmentId.compareTo(b.assessment.assessmentId);
    });

    return sorted;
  }

  static List<double> getRepetitionHistory(
    List<AssessmentProgressData> assessments,
  ) {
    final sorted = sortDetailedChronologically(assessments);

    return sorted.map((item) => item.details.repetitionPercent).toList();
  }

  static List<double> getProlongationHistory(
    List<AssessmentProgressData> assessments,
  ) {
    final sorted = sortDetailedChronologically(assessments);

    return sorted.map((item) => item.details.prolongationPercent).toList();
  }

  static List<double> getBlockHistory(
    List<AssessmentProgressData> assessments,
  ) {
    final sorted = sortDetailedChronologically(assessments);

    return sorted.map((item) => item.details.blockPercent).toList();
  }

  static double? calculateTrendSlope(List<ProgressAssessment> assessments) {
    if (assessments.length < 3) return null;

    final sorted = sortChronologically(assessments);
    final firstDate = sorted.first.completedAt;

    final x = sorted.map((assessment) {
      return assessment.completedAt
              .difference(firstDate)
              .inMilliseconds
              .toDouble() /
          (1000 * 60 * 60 * 24);
    }).toList();

    final y = sorted
        .map((assessment) => assessment.overallStutteringPercent)
        .toList();

    final meanX = x.reduce((a, b) => a + b) / x.length;
    final meanY = y.reduce((a, b) => a + b) / y.length;

    double numerator = 0;
    double denominator = 0;

    for (int i = 0; i < x.length; i++) {
      numerator += (x[i] - meanX) * (y[i] - meanY);
      denominator += (x[i] - meanX) * (x[i] - meanX);
    }

    if (denominator == 0) return null;

    return numerator / denominator;
  }

  static double? calculatePatternTrendSlope(
    List<AssessmentProgressData> assessments,
    double Function(FluencyProfileData) getPercent,
  ) {
    if (assessments.length < 3) return null;

    final sorted = sortDetailedChronologically(assessments);
    final firstDate = sorted.first.assessment.completedAt;

    final x = sorted.map((item) {
      return item.assessment.completedAt
              .difference(firstDate)
              .inMilliseconds
              .toDouble() /
          (1000 * 60 * 60 * 24);
    }).toList();

    final y = sorted.map((item) {
      return getPercent(item.details);
    }).toList();

    final meanX = x.reduce((a, b) => a + b) / x.length;
    final meanY = y.reduce((a, b) => a + b) / y.length;

    double numerator = 0;
    double denominator = 0;

    for (int i = 0; i < x.length; i++) {
      numerator += (x[i] - meanX) * (y[i] - meanY);
      denominator += (x[i] - meanX) * (x[i] - meanX);
    }

    if (denominator == 0) return null;

    return numerator / denominator;
  }

  static double? calculatePatternEstimatedChange(
    List<AssessmentProgressData> assessments,
    double Function(FluencyProfileData) getPercent,
  ) {
    final sorted = sortDetailedChronologically(assessments);

    if (sorted.length < 2) return null;

    if (sorted.length == 2) {
      return calculateChange(
        getPercent(sorted.first.details),
        getPercent(sorted.last.details),
      );
    }

    final slope = calculatePatternTrendSlope(sorted, getPercent);
    if (slope == null) return null;

    final days =
        sorted.last.assessment.completedAt
            .difference(sorted.first.assessment.completedAt)
            .inMilliseconds /
        Duration.millisecondsPerDay;

    return slope * days;
  }
}

class AssessmentProgressData {
  final ProgressAssessment assessment;
  final FluencyProfileData details;

  const AssessmentProgressData({
    required this.assessment,
    required this.details,
  });
}
