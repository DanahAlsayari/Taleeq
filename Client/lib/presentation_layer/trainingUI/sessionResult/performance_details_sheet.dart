import 'package:flutter/material.dart';

import '../../../models/session_result_model.dart';
import '../../../services/practice_session_service.dart'
    show PracticeSessionException;
import '../../../services/session_result_service.dart';
import 'session_result_widgets.dart';

/// Bottom sheet with the detailed performance of the whole session or of one
/// exercise. Up to four exercises use chips; more than four use a dropdown.
Future<void> showPerformanceDetailsSheet(
  BuildContext context, {
  required SessionResultData session,
  int? initialExerciseId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PerformanceDetailsSheet(
      session: session,
      initialExerciseId: initialExerciseId,
    ),
  );
}

class PerformanceDetailsSheet extends StatefulWidget {
  const PerformanceDetailsSheet({
    super.key,
    required this.session,
    this.initialExerciseId,
  });

  final SessionResultData session;
  final int? initialExerciseId;

  @override
  State<PerformanceDetailsSheet> createState() =>
      _PerformanceDetailsSheetState();
}

class _PerformanceDetailsSheetState extends State<PerformanceDetailsSheet> {
  static const int _maxChips = 4;

  final _service = SessionResultService();
  final Map<int, ExerciseResultData> _cache = {};
  final Set<int> _loading = {};
  String? _error;

  /// null = the whole session.
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialExerciseId;

    if (_selectedId != null) {
      _loadExercise(_selectedId!);
    }
  }

  Future<void> _loadExercise(int sessionExerciseId) async {
    if (_cache.containsKey(sessionExerciseId) ||
        _loading.contains(sessionExerciseId)) {
      return;
    }

    setState(() {
      _loading.add(sessionExerciseId);
      _error = null;
    });

    try {
      final data = await _service.fetchExerciseResult(
        widget.session.sessionId,
        sessionExerciseId,
      );

      if (!mounted) return;

      setState(() {
        _cache[sessionExerciseId] = data;
        _loading.remove(sessionExerciseId);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading.remove(sessionExerciseId);
        _error = error is PracticeSessionException
            ? error.message
            : 'تعذر تحميل التفاصيل. يرجى المحاولة مجددًا.';
      });
    }
  }

  void _select(int? sessionExerciseId) {
    setState(() {
      _selectedId = sessionExerciseId;
      _error = null;
    });

    if (sessionExerciseId != null) {
      _loadExercise(sessionExerciseId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: ResultColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5D0C8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'تفاصيل الأداء',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ResultColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSelector(),
                const SizedBox(height: 12),
                ..._buildContent(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Selector -----------------------------------------------------------

  Widget _buildSelector() {
    final exercises = widget.session.exercises;

    if (exercises.length > _maxChips) {
      return _buildDropdown(exercises);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('كل الجلسة', _selectedId == null, () => _select(null)),
          for (final exercise in exercises) ...[
            const SizedBox(width: 8),
            _chip(
              exercise.title,
              _selectedId == exercise.sessionExerciseId,
              () => _select(exercise.sessionExerciseId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ResultColors.teal : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? ResultColors.teal : ResultColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : ResultColors.text,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(List<SessionExerciseSummary> exercises) {
    // 0 means the whole session; real ids are always positive.
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ResultColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedId ?? 0,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: ResultColors.muted,
          ),
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ResultColors.text,
          ),
          items: [
            DropdownMenuItem<int>(
              value: 0,
              child: Text('كل الجلسة (${exercises.length} تمارين)'),
            ),
            for (final exercise in exercises)
              DropdownMenuItem<int>(
                value: exercise.sessionExerciseId,
                child: Text(exercise.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => _select(value == null || value == 0 ? null : value),
        ),
      ),
    );
  }

  // ---- Content ------------------------------------------------------------

  List<Widget> _buildContent() {
    if (_selectedId == null) {
      return [
        _metricsCard('مقاييس الأداء (متوسط الجلسة)', widget.session.scores),
        const SizedBox(height: 12),
        _sessionTechniqueCard(),
        const SizedBox(height: 12),
        _stutteringCard('محسوبة من إجمالي كلمات الجلسة (مو متوسط نسب التمارين).', widget.session.metrics),
      ];
    }

    final id = _selectedId!;

    if (_loading.contains(id)) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(color: ResultColors.teal),
          ),
        ),
      ];
    }

    final data = _cache[id];

    if (data == null) {
      return [
        ResultErrorView(
          message: _error ?? 'تعذر تحميل التفاصيل.',
          onRetry: () => _loadExercise(id),
        ),
      ];
    }

    if (!data.ready) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'نتيجة هذا التمرين لم تجهز بعد.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15,
                color: ResultColors.muted,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      _metricsCard('مقاييس الأداء', data.scores),
      const SizedBox(height: 12),
      _exerciseTechniqueCard(data.technique),
      const SizedBox(height: 12),
      _stutteringCard('النسبة المقدّرة للكلام المتأثر بالتأتأة.', data.metrics),
    ];
  }

  static const String _techniqueHelp =
      'يوضح هل طبّقت التكنيك المطلوب في كل تمرين، ووين كان التطبيق جيد ووين يحتاج تحسين.';

  Widget _card({
    required IconData icon,
    required String title,
    required String help,
    required List<Widget> children,
  }) {
    return ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultSectionHeader(icon: icon, title: title, help: help),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _metricsCard(String title, ResultScores scores) {
    final rows = <(IconData, String, double?, Color)>[
      (Icons.record_voice_over_rounded, 'الطلاقة', scores.fluency, ResultColors.fluency),
      (Icons.graphic_eq_rounded, 'الإيقاع', scores.rhythm, ResultColors.rhythm),
      (Icons.speed_rounded, 'التحكم بالسرعة', scores.speedControl, ResultColors.speed),
      (Icons.task_alt_rounded, 'الالتزام بالمهمة', scores.taskAdherence, ResultColors.adherence),
    ];

    return _card(
      icon: Icons.bar_chart_rounded,
      title: title,
      help: 'درجات من 100 تقيس جودة كلامك في كل جانب.',
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          ResultMetricBar(
            icon: rows[i].$1,
            label: rows[i].$2,
            valueText: formatWholePercent(rows[i].$3),
            fraction: (rows[i].$3 ?? 0) / 100,
            color: rows[i].$4,
          ),
        ],
      ],
    );
  }

  Widget _sessionTechniqueCard() {
    final exercises = widget.session.exercises;
    final applied = widget.session.techniqueApplied;

    return _card(
      icon: Icons.psychology_alt_rounded,
      title: 'تطبيق التكنيك',
      help: _techniqueHelp,
      children: [
        Text(
          'طُبّق التكنيك بشكل جيد في $applied من ${exercises.length} تمارين. '
          'اختر تمرين من فوق لتشوف وين غلطت.',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            height: 1.7,
            color: ResultColors.muted,
          ),
        ),
        for (final exercise in exercises) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: ResultColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ResultColors.text,
                      ),
                    ),
                    if (exercise.techniqueName != null)
                      Text(
                        exercise.techniqueName!,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: ResultColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              TechniqueStatusPill(status: exercise.techniqueStatus),
            ],
          ),
        ],
      ],
    );
  }

  Widget _exerciseTechniqueCard(ExerciseTechniqueResult? technique) {
    if (technique == null) {
      return _card(
        icon: Icons.psychology_alt_rounded,
        title: 'تطبيق التكنيك',
        help: _techniqueHelp,
        children: const [
          Text(
            'هذا التمرين بدون تكنيك محدد.',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              color: ResultColors.muted,
            ),
          ),
        ],
      );
    }

    return _card(
      icon: Icons.psychology_alt_rounded,
      title: 'تطبيق التكنيك',
      help: _techniqueHelp,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                technique.nameAr ?? 'التكنيك',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ResultColors.text,
                ),
              ),
            ),
            TechniqueStatusPill(status: technique.status),
          ],
        ),
        if (technique.description != null) ...[
          const SizedBox(height: 8),
          Text(
            technique.description!,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              height: 1.7,
              color: ResultColors.muted,
            ),
          ),
        ],
        if (technique.appliedWhere.isNotEmpty) ...[
          const SizedBox(height: 16),
          _listTitle('وين طبّقته'),
          for (final line in technique.appliedWhere)
            _bullet(Icons.check_circle_rounded, ResultColors.teal, line),
        ],
        if (technique.improveWhere.isNotEmpty) ...[
          const SizedBox(height: 16),
          _listTitle('وين تحتاج تحسين'),
          for (final line in technique.improveWhere)
            _bullet(Icons.error_rounded, ResultColors.brown, line),
        ],
        if (technique.tip != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ResultColors.tipBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  size: 22,
                  color: ResultColors.brown,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'للمحاولة الجاية: ',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: technique.tip),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      height: 1.7,
                      color: ResultColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _listTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: ResultColors.text,
        ),
      ),
    );
  }

  Widget _bullet(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                height: 1.6,
                color: ResultColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stutteringCard(String note, ResultMetrics metrics) {
    final total = metrics.stuttering;

    // The bars are scaled so that small percentages stay visible.
    double scale(double? v) => ((v ?? 0) / 20).clamp(0.0, 1.0);

    return _card(
      icon: Icons.auto_graph_rounded,
      title: 'نسب التأتأة',
      help: 'نسبة الكلام المتأثر بالتأتأة، مقسومة على تكرار وإطالة وتوقف.',
      children: [
        const Text(
          'نسبة التأتأة الكلية',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ResultColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              formatPercent(total),
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: ResultColors.tealDark,
              ),
            ),
          ),
        ),
        ResultProgressBar(
          fraction: scale(total),
          color: ResultColors.stutterTotal,
          height: 9,
        ),
        const SizedBox(height: 8),
        Text(
          note,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            height: 1.6,
            color: ResultColors.muted,
          ),
        ),
        const SizedBox(height: 18),
        ResultMetricBar(
          icon: Icons.repeat_rounded,
          label: 'التكرار',
          valueText: formatPercent(metrics.repetition),
          fraction: scale(metrics.repetition),
          color: ResultColors.rhythm,
          barHeight: 6,
        ),
        const SizedBox(height: 14),
        ResultMetricBar(
          icon: Icons.graphic_eq_rounded,
          label: 'الإطالة',
          valueText: formatPercent(metrics.prolongation),
          fraction: scale(metrics.prolongation),
          color: ResultColors.speed,
          barHeight: 6,
        ),
        const SizedBox(height: 14),
        ResultMetricBar(
          icon: Icons.pause_circle_rounded,
          label: 'التوقف',
          valueText: formatPercent(metrics.block),
          fraction: scale(metrics.block),
          color: ResultColors.block,
          barHeight: 6,
        ),
      ],
    );
  }
}
