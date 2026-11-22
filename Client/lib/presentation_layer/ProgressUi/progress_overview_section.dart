import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/progress_assessment_model.dart';
import '../../models/session_result_model.dart';
import '../../services/progress_service.dart';
import '../../services/session_result_service.dart';
import '../../theme/taleeq_theme.dart';

/// Progress ← "نظرة عامة".
///
/// One chart of the stuttering percentage over time for the three sources
/// (assessments, sessions, training), a table with the first and last result
/// of each source, and a short summary of what changed.
///
/// The assessments come from the app's existing assessment history
/// (read only); sessions and training come from GET /practice-sessions/overview.
class ProgressOverviewSection extends StatefulWidget {
  const ProgressOverviewSection({
    super.key,
    required this.assessments,
    required this.onStartAssessment,
    required this.onStartSession,
    this.assessmentSections,
  });

  /// Completed assessments (any order).
  final List<ProgressAssessment> assessments;

  /// Assessment patterns and per-task cards (built by the screen).
  final Widget? assessmentSections;

  /// Opens the new-assessment flow.
  final VoidCallback onStartAssessment;

  /// Opens today's practice session.
  final VoidCallback onStartSession;

  @override
  State<ProgressOverviewSection> createState() =>
      _ProgressOverviewSectionState();
}

enum _Source { assessments, sessions, training }

const _sourceNames = {
  _Source.assessments: 'التقييمات',
  _Source.sessions: 'الجلسات',
  _Source.training: 'التدريب',
};

const _sourceColors = {
  _Source.assessments: TaleeqTheme.primaryTeal,
  _Source.sessions: Color(0xFFC9805F),
  _Source.training: Color(0xFF7A9FD1),
};

const _months = [
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

const _patternNames = {
  'repetition': 'التكرار',
  'prolongation': 'الإطالة',
  'block': 'التوقف',
};

class _ProgressOverviewSectionState extends State<ProgressOverviewSection> {
  final _sessionService = SessionResultService();
  final _progressService = ProgressService();

  late Future<ProgressOverviewData> _overviewFuture;

  /// First and last assessment patterns (change = last - first), if loaded.
  Map<String, double>? _assessmentPatternChanges;

  String _period = 'all'; // all | month | week
  _Source? _source; // null = all sources

  DateTime? _selectedDate;
  _Source? _selectedSource;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _sessionService.fetchOverview();
    _loadAssessmentPatterns();
  }

  @override
  void didUpdateWidget(covariant ProgressOverviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assessments.length != widget.assessments.length) {
      _loadAssessmentPatterns();
    }
  }

  List<ProgressAssessment> get _sortedAssessments {
    final list = [...widget.assessments];
    list.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    return list;
  }

  /// Reads the first and last assessment only (read only, existing service).
  Future<void> _loadAssessmentPatterns() async {
    final sorted = _sortedAssessments;

    if (sorted.length < 2) {
      _assessmentPatternChanges = null;
      return;
    }

    try {
      final first = await _progressService.getAssessmentDetails(
        sorted.first.assessmentId,
      );
      final last = await _progressService.getAssessmentDetails(
        sorted.last.assessmentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _assessmentPatternChanges = {
          'repetition': last.repetitionPercent - first.repetitionPercent,
          'prolongation': last.prolongationPercent - first.prolongationPercent,
          'block': last.blockPercent - first.blockPercent,
        };
      });
    } catch (_) {
      // The patterns are optional: the card just uses the other sources.
    }
  }

  // ---------------------------------------------------------------- data

  DateTime? get _periodStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_period == 'week') {
      // Weeks start on Sunday (DateTime.sunday == 7).
      return today.subtract(Duration(days: now.weekday % 7));
    }

    if (_period == 'month') {
      return DateTime(now.year, now.month, 1);
    }

    return null;
  }

  Map<_Source, List<OverviewPoint>> _allSeries(ProgressOverviewData data) {
    return {
      _Source.assessments: [
        for (final item in _sortedAssessments)
          OverviewPoint(
            date: DateTime(
              item.completedAt.toLocal().year,
              item.completedAt.toLocal().month,
              item.completedAt.toLocal().day,
            ),
            stutteringPercent: item.overallStutteringPercent,
          ),
      ],
      _Source.sessions: data.sessionsSeries,
      _Source.training: data.trainingSeries,
    };
  }

  List<OverviewPoint> _inPeriod(List<OverviewPoint> points) {
    final start = _periodStart;

    if (start == null) {
      return points;
    }

    return points.where((item) => !item.date.isBefore(start)).toList();
  }

  String _dateLabel(DateTime date) => '${date.day} ${_months[date.month - 1]}';

  /// "نقطة" with the right Arabic number form.
  String _points(double value) {
    final n = value.round();

    if (n == 1) {
      return 'نقطة واحدة';
    }

    if (n == 2) {
      return 'نقطتان';
    }

    return '$n ${n >= 3 && n <= 10 ? 'نقاط' : 'نقطة'}';
  }

  String _percent(double value) => '${value.toStringAsFixed(0)}%';

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProgressOverviewData>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;

        // Sessions and training are optional: if they cannot be loaded,
        // the overview still shows the assessments.
        final data = snapshot.data ?? const ProgressOverviewData();

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
              'تابع نتائجك وتغيرها بمرور الوقت.',
              style: TextStyle(color: TaleeqTheme.textMuted),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: TaleeqTheme.primaryTeal,
                  ),
                ),
              )
            else ...[
              _chartCard(data),
              const SizedBox(height: 16),
              _highlights(data),
              if (widget.assessmentSections != null) ...[
                const SizedBox(height: 6),
                widget.assessmentSections!,
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _startSessionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.onStartSession,
        icon: const Icon(Icons.play_arrow_rounded, size: 20),
        label: const Text(
          'بدء جلسة',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: TaleeqTheme.primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _startAssessmentButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.onStartAssessment,
        icon: const Icon(Icons.mic_rounded, size: 20),
        label: const Text(
          'بدء تقييم جديد للطلاقة',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: TaleeqTheme.primaryTeal,
          side: const BorderSide(color: TaleeqTheme.primaryTeal),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaleeqTheme.borderSubtle),
        boxShadow: TaleeqTheme.cardShadow,
      ),
      child: child,
    );
  }

  // --------------------------------------------------------------- chart

  Widget _chartCard(ProgressOverviewData data) {
    final all = _allSeries(data);
    final visible = <_Source, List<OverviewPoint>>{
      for (final entry in all.entries)
        if (_source == null || _source == entry.key)
          entry.key: _inPeriod(entry.value),
    };

    final hasPoints = visible.values.any((points) => points.isNotEmpty);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'تطور نسبة التأتأة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'كيف أقرأ المخطط؟',
                onPressed: _showInfo,
                icon: const Icon(Icons.info_outline_rounded),
                color: TaleeqTheme.primaryTeal,
              ),
            ],
          ),
          const Text(
            'النزول = تحسن في التأتأة',
            style: TextStyle(color: TaleeqTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _periodChips(),
          const SizedBox(height: 12),
          if (!hasPoints)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'لا توجد نتائج في هذه الفترة.',
                  style: TextStyle(color: TaleeqTheme.textMuted),
                ),
              ),
            )
          else ...[
            _chart(visible),
            if (_selectedDate != null && _selectedSource != null)
              _tooltip(visible),
          ],
          const SizedBox(height: 12),
          _sourceChips(),
          const SizedBox(height: 14),
          _table(visible, data),
        ],
      ),
    );
  }

  Widget _periodChips() {
    const periods = {'all': 'الكل', 'month': 'هذا الشهر', 'week': 'هذا الأسبوع'};

    return Row(
      children: [
        for (final entry in periods.entries)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: _period == entry.key,
              selectedColor: TaleeqTheme.softTeal,
              onSelected: (_) => setState(() {
                _period = entry.key;
                _selectedDate = null;
                _selectedSource = null;
              }),
            ),
          ),
      ],
    );
  }

  Widget _sourceChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('الكل'),
          selected: _source == null,
          selectedColor: TaleeqTheme.softTeal,
          onSelected: (_) => setState(() {
            _source = null;
            _selectedDate = null;
            _selectedSource = null;
          }),
        ),
        for (final source in _Source.values)
          ChoiceChip(
            avatar: CircleAvatar(
              radius: 5,
              backgroundColor: _sourceColors[source],
            ),
            label: Text(_sourceNames[source]!),
            selected: _source == source,
            selectedColor: TaleeqTheme.softTeal,
            onSelected: (_) => setState(() {
              _source = source;
              _selectedDate = null;
              _selectedSource = null;
            }),
          ),
      ],
    );
  }

  Widget _chart(Map<_Source, List<OverviewPoint>> visible) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = _OverviewChartPainter(
            series: visible,
            selectedDate: _selectedDate,
            selectedSource: _selectedSource,
            dateLabel: _dateLabel,
          );

          return GestureDetector(
            onTapDown: (details) {
              final hit = painter.nearestPoint(
                details.localPosition,
                Size(constraints.maxWidth, 190),
              );

              setState(() {
                _selectedDate = hit?.$2.date;
                _selectedSource = hit?.$1;
              });
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, 190),
              painter: painter,
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(Map<_Source, List<OverviewPoint>> visible) {
    final points = visible[_selectedSource] ?? const <OverviewPoint>[];
    final matches = points.where((item) => item.date == _selectedDate);

    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final point = matches.first;
    final source = _selectedSource!;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TaleeqTheme.darkSlate,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 5, backgroundColor: _sourceColors[source]),
          const SizedBox(width: 8),
          Text(
            '${_sourceNames[source]} · ${_dateLabel(point.date)} · '
            'نسبة التأتأة ${point.stutteringPercent.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showPatternsInfo(List<String> sourceNotes) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كيف حُسب الرقم؟'),
        content: Text(
          'التغير = نسبة النمط في النهاية − نسبته في البداية، بالنقطة المئوية. '
          'السالب يعني تحسنًا.\n\n'
          '${sourceNotes.join('\n')}\n\n'
          'والرقم هو المتوسط بين ما سبق. والمصدر الذي عنده أقل من نتيجتين '
          'لا يدخل في الحساب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كيف أقرأ المخطط؟'),
        content: const Text(
          'كل خط يمثل نسبة التأتأة في نوع من نتائجك: التقييمات، أو الجلسات، '
          'أو التدريب (متوسط اليوم). كلما انخفضت النسبة تحسنت طلاقتك. '
          'اضغط على نقطة لمعرفة تاريخها ونسبتها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- table

  /// Average of the first and of the last results, using the same number
  /// of results on both sides: [cap] at most, or half of them.
  (double, double) _edgeAverages(List<OverviewPoint> points, int cap) {
    if (points.length < 2) {
      final only = points.first.stutteringPercent;
      return (only, only);
    }

    final k = (points.length ~/ 2).clamp(1, cap);

    double average(Iterable<OverviewPoint> items) =>
        items.map((e) => e.stutteringPercent).reduce((a, b) => a + b) /
        items.length;

    return (
      average(points.take(k)),
      average(points.skip(points.length - k)),
    );
  }

  Widget _table(
    Map<_Source, List<OverviewPoint>> visible,
    ProgressOverviewData data,
  ) {
    final rows = <Widget>[];

    for (final source in _Source.values) {
      final points = visible[source];

      if (points == null || points.isEmpty) {
        continue;
      }

      var first = points.first.stutteringPercent;
      var last = points.last.stutteringPercent;
      final count = points.length;

      // Sessions and training: average of the first results against the
      // average of the last ones (the same number on both sides).
      if (source == _Source.sessions) {
        final edges = _edgeAverages(points, 3);
        first = edges.$1;
        last = edges.$2;
      } else if (source == _Source.training) {
        final attempts = _inPeriod(data.trainingAttempts);

        if (attempts.length >= 2) {
          final edges = _edgeAverages(attempts, 5);
          first = edges.$1;
          last = edges.$2;
        }
      }

      final change = last - first;

      final countText = switch (source) {
        _Source.assessments =>
          count == 1 ? 'تقييم واحد' : (count == 2 ? 'تقييمان' : '$count تقييمات'),
        _Source.sessions =>
          count == 1 ? 'جلسة واحدة' : (count == 2 ? 'جلستان' : '$count جلسات'),
        _Source.training =>
          count == 1
              ? 'يوم تدريب واحد'
              : (count == 2 ? 'يوما تدريب' : '$count أيام تدريب'),
      };

      String changeText;

      if (count < 2) {
        changeText = 'نتيجة واحدة';
      } else if (change.abs() < 0.05) {
        changeText = 'لم تتغير';
      } else if (change < 0) {
        changeText = 'انخفضت ${_points(change.abs())}';
      } else {
        changeText = 'ارتفعت ${_points(change)}';
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              CircleAvatar(radius: 5, backgroundColor: _sourceColors[source]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sourceNames[source]!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      countText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TaleeqTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                count < 2
                    ? _percent(last)
                    : '${_percent(first)} ← ${_percent(last)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: TaleeqTheme.softTeal.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  changeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: TaleeqTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نسبة التأتأة: أول نتيجة ← آخر نتيجة، والتغير بالنقطة المئوية.\n'
          'الجلسات والتدريب: متوسط أول النتائج ← متوسط آخرها.',
          style: TextStyle(fontSize: 11, height: 1.6, color: TaleeqTheme.textMuted),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: TaleeqTheme.borderSubtle),
          rows[i],
        ],
      ],
    );
  }

  // ---------------------------------------------------------- highlights

  Widget _highlights(ProgressOverviewData data) {
    final cards = <Widget>[
      ?_assessmentCard(),
      ?_patternsCard(data),
      ?_exercisesCard(data),
    ];

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أبرز ما لاحظناه',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        for (final card in cards) ...[card, const SizedBox(height: 10)],
      ],
    );
  }

  Widget _highlightCard({
    required Color background,
    required Color foreground,
    required String icon,
    required String label,
    required String title,
    String? subtitle,
    List<Widget> extra = const [],
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  icon,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          if (subtitle != null) const SizedBox(height: 6),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF4A5B58),
              ),
            ),
          if (extra.isNotEmpty) const SizedBox(height: 10),
          ...extra,
        ],
      ),
    );
  }

  Widget? _assessmentCard() {
    final sorted = _sortedAssessments;

    if (sorted.isEmpty) {
      return null;
    }

    final first = sorted.first.overallStutteringPercent;
    final last = sorted.last.overallStutteringPercent;

    String title;
    String subtitle;
    String icon;

    if (sorted.length < 2) {
      title = 'هذا تقييمك الأول';
      subtitle = 'نسبة التأتأة ${_percent(last)}. أكمل تقييمًا آخر لمتابعة التغيّر.';
      icon = '•';
    } else if ((last - first).abs() < 0.05) {
      title = 'آخر تقييم مساوٍ لأول تقييم';
      subtitle = 'نسبة التأتأة ثابتة عند ${_percent(last)}.';
      icon = '=';
    } else if (last < first) {
      title = 'آخر تقييم أفضل من أول تقييم';
      subtitle = 'نسبة التأتأة انخفضت من ${_percent(first)} إلى ${_percent(last)}.';
      icon = '▼';
    } else {
      title = 'آخر تقييم أعلى من أول تقييم';
      subtitle = 'نسبة التأتأة ارتفعت من ${_percent(first)} إلى ${_percent(last)}.';
      icon = '▲';
    }

    return _highlightCard(
      background: TaleeqTheme.softTeal.withValues(alpha: 0.55),
      foreground: TaleeqTheme.primaryTeal,
      icon: icon,
      label: 'التقييمات',
      title: title,
      subtitle: subtitle,
      extra: sorted.length < 2
          ? const []
          : [
              _resultRow(
                name: 'نسبة التأتأة',
                change: last - first,
                value: '${_percent(first)} ← ${_percent(last)}',
                lineColor: TaleeqTheme.primaryTeal,
                first: true,
              ),
            ],
    );
  }

  Widget? _patternsCard(ProgressOverviewData data) {
    final sources = <Map<String, double>>[
      ?_assessmentPatternChanges,
      ?data.sessionsPatternChanges,
      ?data.trainingPatternChanges,
    ];

    if (sources.isEmpty) {
      return null;
    }

    final improved = <String>[];
    final worsened = <String>[];
    final averages = <String, double>{};

    // How each source is compared (the same rule as the table above).
    const sourceNotes = [
      'التقييمات: أول تقييم ← آخر تقييم',
      'الجلسات: متوسط أول الجلسات ← متوسط آخرها',
      'التدريب: متوسط أول المحاولات ← متوسط آخرها',
    ];

    for (final entry in _patternNames.entries) {
      final values = [
        for (final source in sources)
          if (source[entry.key] != null) source[entry.key]!,
      ];

      if (values.isEmpty) {
        continue;
      }

      final average = values.reduce((a, b) => a + b) / values.length;
      averages[entry.value] = average;

      if (average <= -0.05) {
        improved.add(entry.value);
      } else if (average >= 0.05) {
        worsened.add(entry.value);
      }
    }

    if (improved.isEmpty && worsened.isEmpty) {
      return null;
    }

    return _highlightCard(
      background: TaleeqTheme.warmCream,
      foreground: const Color(0xFF8A5A1F),
      icon: improved.isNotEmpty ? '↓' : '↑',
      label: 'أنماط التأتأة',
      title: improved.isNotEmpty
          ? 'انخفض: ${improved.join(' و')}'
          : 'ارتفع: ${worsened.join(' و')}',
      subtitle: improved.isNotEmpty && worsened.isNotEmpty
          ? 'وارتفع: ${worsened.join(' و')}'
          : null,
      extra: [
        for (final entry in averages.entries)
          _resultRow(
            name: entry.key,
            change: entry.value,
            value: entry.value.abs() < 0.05
                ? '0.0 نقطة'
                : '${entry.value < 0 ? '−' : '+'}'
                      '${entry.value.abs().toStringAsFixed(1)} نقطة',
            lineColor: const Color(0xFF8A5A1F),
            first: entry.key == averages.keys.first,
            valueWidth: 84,
          ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'متوسط التغيّر في كل المصادر',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFF4A5B58),
                ),
              ),
            ),
            IconButton(
              tooltip: 'كيف حُسب الرقم؟',
              visualDensity: VisualDensity.compact,
              onPressed: () => _showPatternsInfo(sourceNotes),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              color: const Color(0xFF8A5A1F),
            ),
          ],
        ),
      ],
    );
  }

  /// One row of a highlight card: name, change indicator and the numbers.
  Widget _resultRow({
    required String name,
    required double change,
    required String value,
    required Color lineColor,
    bool first = false,
    double valueWidth = 72,
  }) {
    return Column(
      children: [
        if (!first) Divider(height: 1, color: lineColor.withValues(alpha: 0.18)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: TaleeqTheme.darkSlate,
                  ),
                ),
              ),
              _changeBadge(change),
              const SizedBox(width: 14),
              SizedBox(
                width: valueWidth,
                child: Text(
                  value,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TaleeqTheme.darkSlate,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Small indicator of how a result changed: rose, fell or stayed the same.
  Widget _changeBadge(double change) {
    final IconData icon;
    final String text;
    final Color color;

    if (change.abs() < 0.05) {
      icon = Icons.remove_rounded;
      text = 'ثابت';
      color = TaleeqTheme.textMuted;
    } else if (change > 0) {
      icon = Icons.arrow_upward_rounded;
      text = 'ارتفع';
      color = const Color(0xFFB5483B);
    } else {
      icon = Icons.arrow_downward_rounded;
      text = 'انخفض';
      color = TaleeqTheme.primaryTeal;
    }

    return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
    );
  }

  Widget? _exercisesCard(ProgressOverviewData data) {
    // Only types with at least two attempts have a first and a last result.
    final types = data.types.where((item) => item.attempts >= 2).toList();

    if (types.isEmpty) {
      return null;
    }

    const blue = Color(0xFF2F6F9F);

    return _highlightCard(
      background: const Color(0xFFE3EEF8),
      foreground: blue,
      icon: '✓',
      label: 'التمارين',
      title: 'تطور نتائجك في التمارين',
      subtitle: 'نسبة التأتأة في كل نوع، من أول تمرين إلى آخر تمرين:',
      extra: [
        for (var i = 0; i < types.length; i++)
          _resultRow(
            name: types[i].name,
            change: types[i].change,
            value:
                '${_percent(types[i].firstPercent)} ← '
                '${_percent(types[i].lastPercent)}',
            lineColor: blue,
            first: i == 0,
          ),
      ],
    );
  }
}

/// Line chart: date on the x axis, stuttering % on the y axis.
/// 0% is at the top, so an improving (falling) result moves up.
class _OverviewChartPainter extends CustomPainter {
  _OverviewChartPainter({
    required this.series,
    required this.selectedDate,
    required this.selectedSource,
    required this.dateLabel,
  });

  final Map<_Source, List<OverviewPoint>> series;
  final DateTime? selectedDate;
  final _Source? selectedSource;
  final String Function(DateTime) dateLabel;

  static const double _left = 36;
  static const double _right = 12;
  static const double _top = 10;
  static const double _bottom = 30;

  double get _maxPercent {
    var maxValue = 5.0;

    for (final points in series.values) {
      for (final point in points) {
        if (point.stutteringPercent > maxValue) {
          maxValue = point.stutteringPercent;
        }
      }
    }

    // Round up to a multiple of 5 so the grid lines are clean.
    return ((maxValue / 5).ceil() * 5).toDouble();
  }

  ({DateTime min, DateTime max}) get _range {
    DateTime? min;
    DateTime? max;

    for (final points in series.values) {
      for (final point in points) {
        if (min == null || point.date.isBefore(min)) {
          min = point.date;
        }

        if (max == null || point.date.isAfter(max)) {
          max = point.date;
        }
      }
    }

    final now = DateTime.now();
    final fallback = DateTime(now.year, now.month, now.day);

    return (min: min ?? fallback, max: max ?? fallback);
  }

  Offset _position(OverviewPoint point, Size size) {
    final range = _range;
    final width = size.width - _left - _right;
    final height = size.height - _top - _bottom;
    final span = range.max.difference(range.min).inHours;

    final x = span == 0
        ? _left + width / 2
        : _left + width * (point.date.difference(range.min).inHours / span);

    final y = _top + height * (point.stutteringPercent / _maxPercent);

    return Offset(x, y);
  }

  /// The closest point to a tap, within a small distance.
  (_Source, OverviewPoint)? nearestPoint(Offset tap, Size size) {
    (_Source, OverviewPoint)? best;
    var bestDistance = 28.0;

    for (final entry in series.entries) {
      for (final point in entry.value) {
        final distance = (_position(point, size) - tap).distance;

        if (distance < bestDistance) {
          bestDistance = distance;
          best = (entry.key, point);
        }
      }
    }

    return best;
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    TextAlign align = TextAlign.left,
    TextDirection direction = TextDirection.ltr,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: TaleeqTheme.textMuted),
      ),
      textDirection: direction,
    )..layout();

    final dx = switch (align) {
      TextAlign.center => anchor.dx - painter.width / 2,
      TextAlign.right || TextAlign.end => anchor.dx - painter.width,
      _ => anchor.dx,
    };

    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - _top - _bottom;
    final maxPercent = _maxPercent;

    // Horizontal grid and y labels.
    final grid = Paint()
      ..color = TaleeqTheme.borderSubtle
      ..strokeWidth = 1;

    for (var value = 0.0; value <= maxPercent; value += 5) {
      final y = _top + height * (value / maxPercent);
      canvas.drawLine(Offset(_left, y), Offset(size.width - _right, y), grid);
      _text(
        canvas,
        '${value.toStringAsFixed(0)}%',
        Offset(_left - 6, y),
        align: TextAlign.right,
      );
    }

    // X labels: first, middle and last date.
    final range = _range;
    final middle = range.min.add(
      Duration(hours: range.max.difference(range.min).inHours ~/ 2),
    );

    final labelY = size.height - _bottom + 14;
    final spanZero = range.max.difference(range.min).inHours == 0;

    if (spanZero) {
      _text(
        canvas,
        dateLabel(range.min),
        Offset(_left + (size.width - _left - _right) / 2, labelY),
        align: TextAlign.center,
        direction: TextDirection.rtl,
      );
    } else {
      _text(
        canvas,
        dateLabel(range.min),
        Offset(_left, labelY),
        direction: TextDirection.rtl,
      );
      _text(
        canvas,
        dateLabel(middle),
        Offset(_left + (size.width - _left - _right) / 2, labelY),
        align: TextAlign.center,
        direction: TextDirection.rtl,
      );
      _text(
        canvas,
        dateLabel(range.max),
        Offset(size.width - _right, labelY),
        align: TextAlign.right,
        direction: TextDirection.rtl,
      );
    }

    // Lines and points.
    for (final entry in series.entries) {
      final points = entry.value;

      if (points.isEmpty) {
        continue;
      }

      final color = _sourceColors[entry.key]!;
      final line = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;

      final path = Path();

      for (var i = 0; i < points.length; i++) {
        final position = _position(points[i], size);

        if (i == 0) {
          path.moveTo(position.dx, position.dy);
        } else {
          path.lineTo(position.dx, position.dy);
        }
      }

      canvas.drawPath(path, line);

      for (final point in points) {
        final position = _position(point, size);
        final selected =
            entry.key == selectedSource && point.date == selectedDate;

        canvas.drawCircle(position, selected ? 7 : 4, Paint()..color = color);

        if (selected) {
          canvas.drawCircle(position, 4, Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverviewChartPainter oldDelegate) => true;
}
