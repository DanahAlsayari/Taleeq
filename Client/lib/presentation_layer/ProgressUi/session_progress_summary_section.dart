import 'package:flutter/material.dart';

import '../../models/session_result_model.dart';
import '../../services/session_result_service.dart';
import '../../theme/taleeq_theme.dart';

/// Summary of the completed training sessions for the Progress tab
/// (التقدم ← التدريب), shown above the sessions list:
/// completed sessions, total training time, latest and best score, and the
/// stuttering percentage of each session. Filtered by week / month / all.
class SessionProgressSummarySection extends StatefulWidget {
  const SessionProgressSummarySection({super.key});

  @override
  State<SessionProgressSummarySection> createState() =>
      _SessionProgressSummarySectionState();
}

class _SessionProgressSummarySectionState
    extends State<SessionProgressSummarySection> {
  static const _periods = <String, String>{
    'all': 'الكل',
    'week': 'هذا الأسبوع',
    'month': 'هذا الشهر',
  };

  final _service = SessionResultService();

  String _period = 'all';
  late Future<SessionProgressSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchSummary(period: _period);
  }

  void _selectPeriod(String period) {
    if (period == _period) {
      return;
    }

    setState(() {
      _period = period;
      _future = _service.fetchSummary(period: period);
    });
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) {
      return '0 د';
    }

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return minutes == 0 ? '$hours س' : '$hours س $minutes د';
    }

    final secs = seconds % 60;

    if (minutes == 0) {
      return '$seconds ث';
    }

    return secs == 0 ? '$minutes د' : '$minutes د $secs ث';
  }

  String _score(double? value) =>
      value == null ? '--' : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionProgressSummary>(
      future: _future,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;

        // The summary is optional: hide it if it cannot be read.
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _periodChips(),
            const SizedBox(height: 12),
            if (loading || summary == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: TaleeqTheme.primaryTeal,
                    ),
                  ),
                ),
              )
            else if (summary.completedSessions == 0)
              _card(
                child: const Text(
                  'لا توجد جلسات مكتملة في هذه الفترة.',
                  style: TextStyle(color: TaleeqTheme.textMuted),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _statTile(
                      Icons.check_circle_outline_rounded,
                      '${summary.completedSessions}',
                      'جلسات مكتملة',
                      TaleeqTheme.softTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statTile(
                      Icons.timer_outlined,
                      _formatDuration(summary.totalTrainingSeconds),
                      'وقت التدريب',
                      TaleeqTheme.softPeach,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statTile(
                      Icons.flag_outlined,
                      _score(summary.latestScore),
                      'آخر درجة',
                      TaleeqTheme.softTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statTile(
                      Icons.emoji_events_outlined,
                      _score(summary.bestScore),
                      'أعلى درجة',
                      TaleeqTheme.warmCream,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _stutteringCard(summary),
            ],
          ],
        );
      },
    );
  }

  Widget _periodChips() {
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in _periods.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: _period == entry.key,
            selectedColor: TaleeqTheme.softTeal,
            onSelected: (_) => _selectPeriod(entry.key),
          ),
      ],
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

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return _card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: TaleeqTheme.primaryTeal, size: 24),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              // ⁦ ... ⁩ = isolated left-to-right run, so the
              // number always comes before its Arabic unit ("51 ث").
              '⁦$value⁩',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: TaleeqTheme.primaryTeal,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: TaleeqTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stutteringCard(SessionProgressSummary summary) {
    final series = summary.stutteringSeries;
    final change = summary.stutteringChange;

    String message;
    Color color = TaleeqTheme.textMuted;

    if (change == null) {
      message = 'أكمل جلسة أخرى لتظهر لك مقارنة نسبة التأتأة.';
    } else if (change.abs() < 0.1) {
      message = 'نسبة التأتأة لم تتغير بين أول جلسة وآخر جلسة.';
    } else if (change < 0) {
      message =
          'انخفضت نسبة التأتأة ${change.abs().toStringAsFixed(1)}% '
          'بين أول جلسة وآخر جلسة.';
      color = TaleeqTheme.primaryTeal;
    } else {
      message =
          'ارتفعت نسبة التأتأة ${change.toStringAsFixed(1)}% '
          'بين أول جلسة وآخر جلسة.';
      color = const Color(0xFFA5483B);
    }

    // Bars are scaled to the highest value so small changes stay visible.
    var maxValue = 0.0;

    for (final point in series) {
      if (point.stutteringPercent > maxValue) {
        maxValue = point.stutteringPercent;
      }
    }

    // Newest sessions only, so the bars stay readable.
    final shown = series.length > 10
        ? series.sublist(series.length - 10)
        : series;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نسبة التأتأة عبر الجلسات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: TaleeqTheme.darkSlate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical axis title.
              const RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'نسبة التأتأة (%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TaleeqTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(
                            color: Color(0xFFCBD8D5),
                            width: 1.5,
                          ),
                          bottom: BorderSide(
                            color: Color(0xFFCBD8D5),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final point in shown)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      '${point.stutteringPercent.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: TaleeqTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    height: maxValue <= 0
                                        ? 4
                                        : 4 +
                                              70 *
                                                  (point.stutteringPercent /
                                                      maxValue),
                                    decoration: const BoxDecoration(
                                      color: TaleeqTheme.mediumTeal,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Session numbers under the bars.
                    Row(
                      children: [
                        for (final point in shown)
                          Expanded(
                            child: Text(
                              point.sequenceNumber == null
                                  ? ''
                                  : '${point.sequenceNumber}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: TaleeqTheme.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Horizontal axis title.
                    const Text(
                      'رقم الجلسة ←',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TaleeqTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'العمود الأقصر = تأتأة أقل (أفضل)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: TaleeqTheme.primaryTeal,
            ),
          ),
        ],
      ),
    );
  }
}
