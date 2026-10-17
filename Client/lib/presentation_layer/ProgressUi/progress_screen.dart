import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/fluency_profile_data.dart';
import '../../models/progress_assessment_model.dart';
import '../../services/progress_service.dart';
import '../../theme/taleeq_theme.dart';
import '../fluencyUI/fluency_profile_screen.dart';
import '../../services/progress_calculator.dart';

import '../widgets/assesmentWidgets/speech_assesment_intro_screen.dart';
import '../widgets/taleeq_info_modal.dart';
import '../exerciseUI/exercise_result_screen.dart';

class ProgressScreen extends StatefulWidget {
  final int initialTab;

  const ProgressScreen({
    super.key,
    this.initialTab = 0,
  });
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ProgressService _service = ProgressService();

  late Future<List<ProgressAssessment>> _history;
  late Future<List<AssessmentProgressData>> _detailedHistory;

  late int _tab;
  int _assessmentIndex = 0;

  String _arabicNumber(int number) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return number
        .toString()
        .split('')
        .map((digit) => digits[int.parse(digit)])
        .join();
  }

  void _loadProgress() {
    _history = _service.getAssessmentHistory();

    _detailedHistory = _history.then(
      (assessments) => _service.getAllAssessmentDetails(assessments),
    );
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _loadProgress();
  }

  void _retry() {
    setState(() {
      _assessmentIndex = 0;
      _loadProgress();
    });
  }

  Future<void> _retakeAssessment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SpeechAssesmentIntroScreen(isRetake: true),
      ),
    );

    if (!mounted) return;

    _retry();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaleeqTheme.warmBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: TaleeqTheme.warmBackground,
        elevation: 0,
        toolbarHeight: 76,
        centerTitle: false,
        title: Text(
          'تقدّمي',
          style: GoogleFonts.cairo(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: TaleeqTheme.darkSlate,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: TaleeqTheme.softTeal.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _tabButton('نظرة عامة', 0),
                  _tabButton('التقييمات', 1),
                  _tabButton('التدريب', 2),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _historyView(isOverview: true),
                _historyView(isOverview: false),
                _trainingView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected ? TaleeqTheme.cardShadow : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? TaleeqTheme.primaryTeal : TaleeqTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyView({required bool isOverview}) {
    return FutureBuilder<List<ProgressAssessment>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: TaleeqTheme.primaryTeal),
          );
        }

        if (snapshot.hasError) {
          return _emptyState(
            icon: Icons.wifi_off_rounded,
            title: 'تعذر تحميل البيانات',
            subtitle: 'تحقق من الاتصال وحاول مرة أخرى.',
            retry: true,
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return _emptyState(
            icon: Icons.insights_outlined,
            title: 'لا توجد تقييمات مكتملة',
            subtitle: 'ستظهر نتائج تقييماتك هنا بعد إكمالها.',
            goHome: true,
          );
        }

        return isOverview ? _overviewView(history) : _assessmentsView(history);
      },
    );
  }

  ({String title, String message, IconData icon, Color color}) _getPatternTrend(
    List<AssessmentProgressData> history,
    String patternName,
    double Function(FluencyProfileData) getPercent,
  ) {
    final sorted = ProgressCalculator.sortDetailedChronologically(history);

    if (sorted.isEmpty) {
      return (
        title: 'لا توجد نتائج متاحة',
        message: 'لا تتوفر بيانات كافية لعرض نتيجة $patternName.',
        icon: Icons.info_outline_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (sorted.length == 1) {
      return (
        title: 'هذه أول نتيجة لـ$patternName',
        message: 'ستظهر مقارنة تطور هذا النمط بعد إجراء تقييم آخر.',
        icon: Icons.info_outline_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (sorted.length == 2) {
      final previous = getPercent(sorted.first.details);
      final current = getPercent(sorted.last.details);
      final change = ProgressCalculator.calculateChange(previous, current);

      if (change.abs() < 0.000001) {
        return (
          title: '$patternName لم يتغير',
          message:
              'بقيت نسبة $patternName كما هي في التقييمين، '
              'ويمكن متابعة تغيرها في التقييمات القادمة.',
          icon: Icons.trending_flat_rounded,
          color: TaleeqTheme.textMuted,
        );
      }

      if (change < 0) {
        return (
          title: '$patternName أصبح أقل',
          message:
              'انخفضت نسبة $patternName بمقدار '
              '${change.abs().toStringAsFixed(1)} نقطة مئوية '
              'مقارنة بالتقييم السابق. وهذا مؤشر إيجابي.',
          icon: Icons.trending_down_rounded,
          color: TaleeqTheme.primaryTeal,
        );
      }

      return (
        title: '$patternName أصبح أكثر',
        message:
            'ارتفعت نسبة $patternName بمقدار '
            '${change.toStringAsFixed(1)} نقطة مئوية '
            'مقارنة بالتقييم السابق. ويُفضّل متابعة هذا الجانب في التقييمات القادمة.',
        icon: Icons.trending_up_rounded,
        color: TaleeqTheme.darkSlate,
      );
    }

    final slope = ProgressCalculator.calculatePatternTrendSlope(
      sorted,
      getPercent,
    );

    if (slope == null) {
      return (
        title: 'لا يمكن تحديد التغير حاليًا',
        message:
            'لا تتوفر معلومات كافية لمعرفة كيف تغير $patternName مع الوقت.',
        icon: Icons.info_outline_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (slope.abs() < 0.000001) {
      return (
        title: '$patternName لم يتغير بشكل واضح',
        message:
            'لا تُظهر نتائج التقييمات تغيرًا واضحًا في نسبة $patternName '
            'خلال فترة المتابعة.',
        icon: Icons.trending_flat_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (slope < 0) {
      return (
        title: '$patternName أصبح أقل',
        message:
            'تُظهر نتائج التقييمات انخفاضًا في نسبة $patternName '
            'مع مرور الوقت. وهذا مؤشر إيجابي.',
        icon: Icons.trending_down_rounded,
        color: TaleeqTheme.primaryTeal,
      );
    }
    return (
      title: '$patternName أصبح أكثر',
      message:
          'تُظهر نتائج التقييمات ارتفاعًا في نسبة $patternName '
          'مع مرور الوقت. ويُفضّل متابعة هذا الجانب في التقييمات القادمة.',
      icon: Icons.trending_up_rounded,
      color: TaleeqTheme.darkSlate,
    );
  }

  double? _getTaskPercent(FluencyProfileData details, String taskType) {
    for (final task in details.taskResults) {
      if (task.taskType == taskType) {
        return task.percent;
      }
    }

    return null;
  }

  List<AssessmentProgressData> _getTaskHistory(
    List<AssessmentProgressData> history,
    String taskType,
  ) {
    final available = history.where((assessment) {
      return _getTaskPercent(assessment.details, taskType) != null;
    }).toList();

    return ProgressCalculator.sortDetailedChronologically(available);
  }

  ({String title, String message, IconData icon, Color color}) _getTaskTrend(
    List<AssessmentProgressData> history,
    String taskType,
    String taskName,
  ) {
    final sorted = _getTaskHistory(history, taskType);

    if (sorted.isEmpty) {
      return (
        title: 'لا توجد نتائج متاحة',
        message: 'لا تتوفر نتائج لهذه المهمة حاليًا.',
        icon: Icons.info_outline_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (sorted.length == 1) {
      return (
        title: 'هذه أول نتيجة للمهمة',
        message: 'ستظهر المقارنة بعد التقييم القادم.',
        icon: Icons.info_outline_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (sorted.length == 2) {
      final previous = _getTaskPercent(sorted.first.details, taskType)!;
      final current = _getTaskPercent(sorted.last.details, taskType)!;

      final change = ProgressCalculator.calculateChange(previous, current);

      if (change.abs() < 0.000001) {
        return (
          title: 'لم تتغير النسبة',
          message: 'لم تتغير نسبة التأتأة مقارنة بالتقييم السابق.',
          icon: Icons.trending_flat_rounded,
          color: TaleeqTheme.textMuted,
        );
      }

      if (change < 0) {
        return (
          title: 'انخفضت نسبة التأتأة',
          message:
              'انخفضت النسبة بمقدار ${change.abs().toStringAsFixed(1)} '
              'نقطة مئوية مقارنة بالتقييم السابق. وهذا مؤشر إيجابي.',
          icon: Icons.trending_down_rounded,
          color: TaleeqTheme.primaryTeal,
        );
      }

      return (
        title: 'ارتفعت نسبة التأتأة',
        message:
            'ارتفعت النسبة بمقدار ${change.toStringAsFixed(1)} '
            'نقطة مئوية مقارنة بالتقييم السابق.',
        icon: Icons.trending_up_rounded,
        color: TaleeqTheme.darkSlate,
      );
    }

    final slope = ProgressCalculator.calculatePatternTrendSlope(
      sorted,
      (details) => _getTaskPercent(details, taskType)!,
    );

    if (slope == null) {
      return (
        title: 'لا يمكن تحديد التغير حاليًا',
        message: 'لا تتوفر معلومات زمنية كافية للمقارنة.',
        icon: Icons.info_outline_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (slope.abs() < 0.000001) {
      return (
        title: 'لا يظهر تغير واضح',
        message: 'لا تُظهر تقييماتك تغيرًا واضحًا في نسبة التأتأة.',
        icon: Icons.trending_flat_rounded,
        color: TaleeqTheme.textMuted,
      );
    }

    if (slope < 0) {
      return (
        title: 'انخفضت نسبة التأتأة',
        message: 'تُظهر تقييماتك انخفاضًا في نسبة التأتأة مع الوقت.',
        icon: Icons.trending_down_rounded,
        color: TaleeqTheme.primaryTeal,
      );
    }

    return (
      title: 'ارتفعت نسبة التأتأة',
      message: 'تُظهر تقييماتك ارتفاعًا في نسبة التأتأة مع الوقت.',
      icon: Icons.trending_up_rounded,
      color: TaleeqTheme.darkSlate,
    );
  }

  Widget _patternRow(
    String arabicName,
    String englishName,
    double? percent,
    String trendTitle,
    String trendMessage,
    IconData trendIcon,
    Color trendColor,
  ) {
    String description;

    switch (englishName.toLowerCase()) {
      case 'repetition':
        description = 'تكرار لا إرادي للأصوات أو المقاطع اللفظية الأولى للكلمات (مثل: قـ-قـ-قال).';
        break;
      case 'prolongation':
        description = 'مد الصوت الصامت أو الصائت بشكل غير مقصود أثناء نطق الكلمة (مثل: سسسـارة).';
        break;
      case 'block':
        description =
            'انحباس مؤقت لتدفق الهواء والصوت مما يعيق خروج الكلمة لحظياً.';
        break;
      default:
        description = 'لا يتوفر وصف لهذا النمط.';
    }

    return InkWell(
      onTap: () => showTaleeqInfoModal(
        context,
        title: '$arabicName ($englishName)',
        category: 'نمط عدم الطلاقة',
        description: description,
        icon: Icons.hearing_rounded,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$arabicName ($englishName)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TaleeqTheme.darkSlate,
                    ),
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      percent == null
                          ? '—'
                          : percent.abs() < 0.05
                          ? '0.0'
                          : '${percent < 0 ? '−' : '+'}${percent.abs().toStringAsFixed(1)}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: percent == null || percent.abs() < 0.05
                            ? TaleeqTheme.textMuted
                            : percent < 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'نقطة مئوية',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: TaleeqTheme.textMuted,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: TaleeqTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(trendIcon, size: 17, color: trendColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trendTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: trendColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trendMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: TaleeqTheme.darkSlate,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskRow(
    String taskName,
    double? percent,
    String trendTitle,
    String trendMessage,
    IconData trendIcon,
    Color trendColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  taskName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: TaleeqTheme.darkSlate,
                  ),
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    percent == null
                        ? '—'
                        : percent.abs() < 0.05
                        ? '0.0'
                        : '${percent < 0 ? '−' : '+'}${percent.abs().toStringAsFixed(1)}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: percent == null || percent.abs() < 0.05
                          ? TaleeqTheme.textMuted
                          : percent < 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'نقطة مئوية',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: TaleeqTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(trendIcon, size: 17, color: trendColor),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trendTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: trendColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trendMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TaleeqTheme.darkSlate,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewView(List<ProgressAssessment> history) {
    final chronological = ProgressCalculator.getOverallTrend(history);

    final latest = ProgressCalculator.getLatestAssessment(history)!;

    final trendSlope = ProgressCalculator.calculateTrendSlope(history);
    String trendMessage;
    IconData trendIcon;
    Color trendColor;

    if (history.length == 1) {
      trendMessage = 'هذا تقييمك الأول. أكمل تقييمات أخرى لمتابعة تطورك.';
      trendIcon = Icons.info_outline_rounded;
      trendColor = TaleeqTheme.textMuted;
    } else if (history.length == 2) {
      final change = ProgressCalculator.getOverallChangeFromPrevious(history)!;

      if (change < 0) {
        trendMessage =
            'انخفضت نسبة التأتأة بمقدار ${change.abs().toStringAsFixed(1)} نقطة مئوية بين تقييميك.';
        trendIcon = Icons.trending_down_rounded;
        trendColor = TaleeqTheme.primaryTeal;
      } else if (change > 0) {
        trendMessage =
            'ارتفعت نسبة التأتأة بمقدار ${change.toStringAsFixed(1)} نقطة مئوية بين تقييميك.';
        trendIcon = Icons.trending_up_rounded;
        trendColor = TaleeqTheme.darkSlate;
      } else {
        trendMessage = 'لم تتغير نسبة التأتأة بين تقييميك.';
        trendIcon = Icons.trending_flat_rounded;
        trendColor = TaleeqTheme.textMuted;
      }
    } else if (trendSlope == null) {
      trendMessage = 'لا تتوفر معلومات زمنية كافية لمعرفة تطور طلاقتك.';
      trendIcon = Icons.info_outline_rounded;
      trendColor = TaleeqTheme.textMuted;
    } else if (trendSlope.abs() < 0.000001) {
      trendMessage = 'لا يظهر تغير واضح في نسبة التأتأة خلال فترة المتابعة.';
      trendIcon = Icons.trending_flat_rounded;
      trendColor = TaleeqTheme.textMuted;
    } else if (trendSlope < 0) {
      trendMessage = 'تُظهر تقييماتك انخفاضًا في نسبة التأتأة مع الوقت.';
      trendIcon = Icons.trending_down_rounded;
      trendColor = TaleeqTheme.primaryTeal;
    } else {
      trendMessage = 'تُظهر تقييماتك ارتفاعًا في نسبة التأتأة مع الوقت.';
      trendIcon = Icons.trending_up_rounded;
      trendColor = TaleeqTheme.darkSlate;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        const Text(
          'رحلة تطور طلاقتك',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: TaleeqTheme.darkSlate,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'تابع نتائج تقييماتك وتغيرها بمرور الوقت.',
          style: TextStyle(color: TaleeqTheme.textMuted),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _retakeAssessment,
            icon: const Icon(Icons.mic_rounded, size: 22),
            label: const Text(
              'بدء تقييم جديد للطلاقة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: TaleeqTheme.primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تطور نسبة التأتأة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              const Text(
                'انخفاض النسبة يشير إلى تحسن في الطلاقة.',
                style: TextStyle(color: TaleeqTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 190,
                child: _TrendChart(assessments: chronological),
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  ' نتائج التقييمات',
                  style: TextStyle(fontSize: 11, color: TaleeqTheme.textMuted),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'نسبة التأتأة الحالية',
                style: const TextStyle(
                  fontSize: 12,
                  color: TaleeqTheme.textMuted,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${latest.overallStutteringPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: TaleeqTheme.primaryTeal,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'كيف تتطور طلاقتك؟',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: TaleeqTheme.darkSlate,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(trendIcon, color: trendColor, size: 23),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      trendMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: TaleeqTheme.darkSlate,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أنماط عدم الطلاقة',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: TaleeqTheme.darkSlate,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'تعرّف على تغير أنماط التأتأة لديك عبر تقييماتك.',
                style: TextStyle(fontSize: 12, color: TaleeqTheme.textMuted),
              ),

              const SizedBox(height: 16),

              FutureBuilder<List<AssessmentProgressData>>(
                future: _detailedHistory,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: TaleeqTheme.primaryTeal,
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text(
                      'تعذر تحميل تفاصيل أنماط عدم الطلاقة.',
                      style: TextStyle(color: TaleeqTheme.textMuted),
                    );
                  }
                  final detailedHistory =
                      ProgressCalculator.sortDetailedChronologically(
                        snapshot.data!,
                      );

                  if (detailedHistory.isEmpty) {
                    return const Text(
                      'لا تتوفر تفاصيل للتقييمات حاليًا.',
                      style: TextStyle(color: TaleeqTheme.textMuted),
                    );
                  }

                  final repetitionChange =
                      ProgressCalculator.calculatePatternEstimatedChange(
                        detailedHistory,
                        (details) => details.repetitionPercent,
                      );

                  final prolongationChange =
                      ProgressCalculator.calculatePatternEstimatedChange(
                        detailedHistory,
                        (details) => details.prolongationPercent,
                      );

                  final blockChange =
                      ProgressCalculator.calculatePatternEstimatedChange(
                        detailedHistory,
                        (details) => details.blockPercent,
                      );

                  final repetitionTrend = _getPatternTrend(
                    detailedHistory,
                    'التكرار',
                    (details) => details.repetitionPercent,
                  );

                  final prolongationTrend = _getPatternTrend(
                    detailedHistory,
                    'الإطالة',
                    (details) => details.prolongationPercent,
                  );

                  final blockTrend = _getPatternTrend(
                    detailedHistory,
                    'التوقف',
                    (details) => details.blockPercent,
                  );
                  return Column(
                    children: [
                      _patternRow(
                        'التكرار',
                        'Repetition',
                        repetitionChange,
                        repetitionTrend.title,
                        repetitionTrend.message,
                        repetitionTrend.icon,
                        repetitionTrend.color,
                      ),
                      const Divider(height: 24),
                      _patternRow(
                        'الإطالة',
                        'Prolongation',
                        prolongationChange,
                        prolongationTrend.title,
                        prolongationTrend.message,
                        prolongationTrend.icon,
                        prolongationTrend.color,
                      ),
                      const Divider(height: 24),
                      _patternRow(
                        'التوقف',
                        'Block',
                        blockChange,
                        blockTrend.title,
                        blockTrend.message,
                        blockTrend.icon,
                        blockTrend.color,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أداؤك في مهام التقييم',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: TaleeqTheme.darkSlate,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'تابع نسبة التأتأة في كل مهمة عبر تقييماتك.',
                style: TextStyle(fontSize: 12, color: TaleeqTheme.textMuted),
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<AssessmentProgressData>>(
                future: _detailedHistory,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: TaleeqTheme.primaryTeal,
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text(
                      'تعذر تحميل نتائج مهام التقييم.',
                      style: TextStyle(color: TaleeqTheme.textMuted),
                    );
                  }

                  final history = snapshot.data!;

                  if (history.isEmpty) {
                    return const Text(
                      'لا تتوفر نتائج للمهام حاليًا.',
                      style: TextStyle(color: TaleeqTheme.textMuted),
                    );
                  }

                  Widget buildTask(String taskType, String taskName) {
                    final taskHistory = _getTaskHistory(history, taskType);

                    final percent =
                        ProgressCalculator.calculatePatternEstimatedChange(
                          taskHistory,
                          (details) => _getTaskPercent(details, taskType)!,
                        );

                    final trend = _getTaskTrend(history, taskType, taskName);

                    return _taskRow(
                      taskName,
                      percent,
                      trend.title,
                      trend.message,
                      trend.icon,
                      trend.color,
                    );
                  }

                  return Column(
                    children: [
                      buildTask('task_1', 'القراءة بصوت عالٍ'),
                      const Divider(height: 24),
                      buildTask('task_2', 'وصف الصورة'),
                      const Divider(height: 24),
                      buildTask('task_3', 'التحدث العفوي'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assessmentsView(List<ProgressAssessment> history) {
    final index = _assessmentIndex.clamp(0, history.length - 1);
    final selected = history[index];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TaleeqTheme.borderSubtle),
              boxShadow: TaleeqTheme.cardShadow,
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (history.length > 1)
                  IconButton(
                    tooltip: 'تقييم أحدث',

                    onPressed: index > 0
                        ? () => setState(() => _assessmentIndex--)
                        : null,

                    icon: const Icon(Icons.chevron_left_rounded),
                    color: TaleeqTheme.primaryTeal,
                  ),

                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        history.length == 1
                            ? 'أحدث تقييم'
                            : index == 0
                            ? 'أحدث تقييم • ١ من ${_arabicNumber(history.length)}'
                            : 'تقييم ${_arabicNumber(index + 1)} من ${_arabicNumber(history.length)}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TaleeqTheme.darkSlate,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(selected.completedAt),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: TaleeqTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                if (history.length > 1)
                  IconButton(
                    tooltip: 'تقييم أقدم',

                    onPressed: index < history.length - 1
                        ? () => setState(() => _assessmentIndex++)
                        : null,

                    icon: const Icon(Icons.chevron_right_rounded),
                    color: TaleeqTheme.primaryTeal,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _AssessmentDetails(
            key: ValueKey(selected.assessmentId),
            assessmentId: selected.assessmentId,
            service: _service,
          ),
        ),
      ],
    );
  }

  Widget _trainingView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        const Text(
          'سجل التدريب',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'تابع تمارينك وجلساتك التدريبية.',
          style: TextStyle(color: TaleeqTheme.textMuted),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _trainingTile(
                Icons.menu_book_rounded,
                'Exercises',
                TaleeqTheme.softTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _trainingTile(
                Icons.forum_outlined,
                'Sessions',
                TaleeqTheme.softPeach,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
SizedBox(
  height: 1550,
  child: const ExerciseResultScreen(
    embedded: true,
  ),
),
      ],
    );
  }

  Widget _trainingTile(IconData icon, String label, Color color) {
    return _surface(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: TaleeqTheme.primaryTeal, size: 28),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool retry = false,
    bool goHome = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: TaleeqTheme.mediumTeal),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TaleeqTheme.textMuted),
            ),
            if (retry || goHome) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: goHome
                    ? () => Navigator.of(context)
                          .pushNamedAndRemoveUntil('/home', (route) => false)
                    : _retry,
                child: Text(
                  goHome ? 'العودة للصفحة الرئيسية' : 'إعادة المحاولة',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _surface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaleeqTheme.borderSubtle),
        boxShadow: TaleeqTheme.cardShadow,
      ),
      child: child,
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _AssessmentDetails extends StatefulWidget {
  final int assessmentId;
  final ProgressService service;

  const _AssessmentDetails({
    super.key,
    required this.assessmentId,
    required this.service,
  });

  @override
  State<_AssessmentDetails> createState() => _AssessmentDetailsState();
}

class _AssessmentDetailsState extends State<_AssessmentDetails> {
  late Future<FluencyProfileData> _future;

  @override
  void initState() {
    super.initState();

    _future = widget.service.getAssessmentDetails(widget.assessmentId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FluencyProfileData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: TaleeqTheme.primaryTeal),
          );
        }

        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل تفاصيل هذا التقييم.'));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('لا توجد بيانات لهذا التقييم.'));
        }

        return FluencyProfileScreen(
          profileData: snapshot.data!,
          isHistoryView: true,
        );
      },
    );
  }
}

class _TrendChart extends StatefulWidget {
  final List<ProgressAssessment> assessments;

  const _TrendChart({required this.assessments});

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? selectedIndex;
  @override
  Widget build(BuildContext context) {
    if (widget.assessments.length == 1) {
      return const Center(
        child: Text(
          'أكمل تقييمًا آخر لعرض تطور النتائج.',
          textAlign: TextAlign.center,
          style: TextStyle(color: TaleeqTheme.textMuted),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        final width = context.size?.width ?? 0;
        if (width <= 60) return;

        final assessments = widget.assessments;

        final chartWidth = width - 60;
        final tapX = details.localPosition.dx;
        final tapY = details.localPosition.dy;

        final values = assessments
            .map((assessment) => assessment.overallStutteringPercent)
            .toList();

        final minPercent = values.reduce(math.min);
        final maxPercent = values.reduce(math.max);

        final range = math.max(10.0, maxPercent - minPercent);
        final minValue = math.max(0.0, minPercent - range);
        final maxValue = maxPercent + range;

        final height = context.size?.height ?? 190;
        final chartHeight = height - 18 - 38;
        int nearestIndex = 0;
        double nearestDistance = double.infinity;

        for (int i = 0; i < assessments.length; i++) {
          final x = 30 + chartWidth * i / (assessments.length - 1);
          final y =
              18 +
              chartHeight *
                  (1 - (values[i] - minValue) / (maxValue - minValue));

          final dx = tapX - x;
          final dy = tapY - y;

          final distance = math.sqrt(dx * dx + dy * dy);

          if (distance < nearestDistance) {
            nearestDistance = distance;
            nearestIndex = i;
          }
        }

        if (nearestDistance <= 24) {
          setState(() {
            selectedIndex = nearestIndex;
          });
        }
      },
      onLongPressEnd: (details) {
        setState(() {
          selectedIndex = null;
        });
      },
      child: Stack(
        children: [
          CustomPaint(
            painter: _TrendPainter(assessments: widget.assessments),
            child: const SizedBox.expand(),
          ),

          if (selectedIndex != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final assessments = widget.assessments;
                  final index = selectedIndex!;
                  final assessment = assessments[index];

                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  final chartWidth = width - 60;
                  final chartHeight = height - 18 - 38;

                  final values = assessments
                      .map((a) => a.overallStutteringPercent)
                      .toList();

                  final minPercent = values.reduce(math.min);
                  final maxPercent = values.reduce(math.max);

                  final range = math.max(10.0, maxPercent - minPercent);
                  final minValue = math.max(0.0, minPercent - range);
                  final maxValue = maxPercent + range;

                  final x = 30 + chartWidth * index / (assessments.length - 1);
                  final y =
                      18 +
                      chartHeight *
                          (1 -
                              (assessment.overallStutteringPercent - minValue) /
                                  (maxValue - minValue));
                  final date = assessment.completedAt.toLocal();

                  const tooltipWidth = 135.0;
                  const tooltipHeight = 44.0;

                  final left = (x - tooltipWidth / 2)
                      .clamp(0.0, math.max(0.0, width - tooltipWidth))
                      .toDouble();

                  final top = (y - tooltipHeight - 12)
                      .clamp(0.0, math.max(0.0, height - tooltipHeight))
                      .toDouble();

                  return Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: top,
                        child: IgnorePointer(
                          child: Container(
                            width: tooltipWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: TaleeqTheme.darkSlate,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    const Text(
                                      'نسبة التأتأة:',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${assessment.overallStutteringPercent.toStringAsFixed(1)}%',
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<ProgressAssessment> assessments;

  const _TrendPainter({required this.assessments});

  List<double> get values => assessments
      .map((assessment) => assessment.overallStutteringPercent)
      .toList();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const horizontalPadding = 30.0;
    const topPadding = 18.0;
    const bottomPadding = 38.0;

    final chartWidth = size.width - horizontalPadding * 2;
    final chartHeight = size.height - topPadding - bottomPadding;

    final minPercent = values.reduce(math.min);
    final maxPercent = values.reduce(math.max);

    final range = math.max(10.0, maxPercent - minPercent);
    final minValue = math.max(0.0, minPercent - range);
    final maxValue = maxPercent + range;
    Offset pointAt(int index) {
      final x = horizontalPadding + chartWidth * index / (values.length - 1);

      final y =
          topPadding +
          chartHeight *
              (1 - (values[index] - minValue) / (maxValue - minValue));

      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = TaleeqTheme.borderSubtle
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight * i / 4;

      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(size.width - horizontalPadding, y),
        gridPaint,
      );
    }

    final linePaint = Paint()
      ..color = TaleeqTheme.primaryTeal
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);

    for (var i = 1; i < values.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = TaleeqTheme.primaryTeal;

    for (var i = 0; i < values.length; i++) {
      final point = pointAt(i);

      canvas.drawCircle(point, 4, dotPaint);
    }
    final labelIndices = <int>{0, assessments.length - 1};

    final availableLabels = math.max(2, (chartWidth / 75).floor());

    if (assessments.length <= availableLabels) {
      labelIndices.addAll(List.generate(assessments.length, (index) => index));
    }

    for (final index in labelIndices) {
      final date = assessments[index].completedAt.toLocal();

      const months = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];

      final dateText = '${date.day} ${months[date.month - 1]}';

      final textPainter = TextPainter(
        text: TextSpan(
          text: dateText,
          style: const TextStyle(color: TaleeqTheme.textMuted, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = pointAt(index).dx;

      textPainter.paint(
        canvas,
        Offset(
          (x - textPainter.width / 2)
              .clamp(0.0, size.width - textPainter.width)
              .toDouble(),
          size.height - 22,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    if (oldDelegate.assessments.length != assessments.length) {
      return true;
    }

    for (var i = 0; i < assessments.length; i++) {
      final oldAssessment = oldDelegate.assessments[i];
      final newAssessment = assessments[i];

      if (oldAssessment.assessmentId != newAssessment.assessmentId ||
          oldAssessment.completedAt != newAssessment.completedAt ||
          oldAssessment.overallStutteringPercent !=
              newAssessment.overallStutteringPercent) {
        return true;
      }
    }

    return false;
  }
}
