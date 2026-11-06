import 'package:flutter/material.dart';
import 'package:client/theme/taleeq_theme.dart';
import '../widgets/main_navigation_screen.dart';

class ScenarioResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final String scenarioName;

  const ScenarioResultScreen({
    super.key,
    required this.result,
    required this.scenarioName,
  });

  double? _number(Map<String, dynamic> map, String key) =>
      (map[key] as num?)?.toDouble();

  @override
  Widget build(BuildContext context) {
    final scores = Map<String, dynamic>.from(result['scores'] ?? {});
    final metrics = Map<String, dynamic>.from(result['metrics'] ?? {});
    final feedback = Map<String, dynamic>.from(result['feedback'] ?? {});
    final events = result['speech_events'] is List
        ? List<dynamic>.from(result['speech_events'])
        : <dynamic>[];

    final fluency = _number(scores, 'fluency_score');
    final rhythm = _number(scores, 'rhythm_score');
    final stuttering = _number(metrics, 'stuttering_percent');
    final repetition = _number(metrics, 'repetition_percent');
    final prolongation = _number(metrics, 'prolongation_percent');
    final blocks = _number(metrics, 'block_percent');
    final duration = (result['duration_seconds'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 36),
                Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD8EAE7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        color: Color(0xFF287D78),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'أحسنتِ، أكملتِ السيناريو',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF203E3A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  scenarioName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF7A8E8B),
                  ),
                ),
                const SizedBox(height: 20),
                _card(
                  child: Column(
                    children: [
                      const Text(
                        'مؤشر الطلاقة',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF203E3A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        fluency == null ? 'غير متاح' : '${fluency.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: Color(0xFF203E3A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'مدة المحادثة: ${_formatDuration(duration)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7A8E8B),
                        ),
                      ),
                      const Divider(
                        color: Color.fromARGB(255, 210, 225, 233),
                        height: 28,
                      ),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'نقطة قوة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF203E3A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          (feedback['strength'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.7,
                            color: Color(0xFF526F6A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'نقطة للتحسين',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF203E3A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          (feedback['improvement'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.7,
                            color: Color(0xFF526F6A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDetails(
                      context,
                      scores: scores,
                      metrics: metrics,
                      events: events,
                      rhythm: rhythm,
                      stuttering: stuttering,
                      repetition: repetition,
                      prolongation: prolongation,
                      blocks: blocks,
                    ),
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: const Text(
                      'عرض تفاصيل الأداء',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF287D78),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) =>
                              const MainNavigationScreen(initialIndex: 1),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'العودة للتدريب',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  void _showDetails(
    BuildContext context, {
    required Map<String, dynamic> scores,
    required Map<String, dynamic> metrics,
    required List<dynamic> events,
    required double? rhythm,
    required double? stuttering,
    required double? repetition,
    required double? prolongation,
    required double? blocks,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFCFAF6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DDDA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'تفاصيل الأداء',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF203E3A),
                  ),
                ),
                const SizedBox(height: 20),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'مقاييس الأداء',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF006B63),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _metricRow(
                        'الطلاقة',
                        _number(scores, 'fluency_score'),
                        Icons.record_voice_over_rounded,
                        const Color(0xFF087F73),
                      ),
                      _metricRow(
                        'الإيقاع',
                        rhythm,
                        Icons.graphic_eq_rounded,
                        const Color(0xFF4D9BA0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'نسب التأتأة',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF006B63),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _totalStuttering(stuttering),
                      const SizedBox(height: 20),
                      _metricRow(
                        'التكرار',
                        repetition,
                        Icons.repeat_rounded,
                        const Color(0xFF087F73),
                      ),
                      _metricRow(
                        'الإطالة',
                        prolongation,
                        Icons.graphic_eq_rounded,
                        const Color(0xFF4D9BA0),
                      ),
                      _metricRow(
                        'التوقف',
                        blocks,
                        Icons.pause_circle_outline_rounded,
                        const Color(0xFFC47A50),
                      ),
                      const Text(
                        'النسب تقديرية، وتحسب لكل نوع من إجمالي المقاطع الصوتية المنطوقة.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF8A9694),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'أحداث التأتأة المرصودة',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF006B63),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (events.isEmpty)
                        const Text(
                          'لا توجد أحداث محددة ضمن التحليل.',
                          style: TextStyle(
                            color: Color(0xFF7A8E8B),
                            height: 1.6,
                          ),
                        )
                      else
                        ...events.map((event) {
                          final item = Map<String, dynamic>.from(event);
                          final type = item['event_type']?.toString() ?? '';
                          final label = {
                                'repetition': 'تكرار',
                                'prolongation': 'إطالة',
                                'block': 'توقف',
                              }[type] ??
                              type;
                          final confidence =
                              (item['confidence'] as num?)?.toDouble();
                          final contextText = item['context']?.toString() ?? '';
                          final position = {
                                'beginning': 'بداية الكلمة',
                                'middle': 'وسط الكلمة',
                                'end': 'نهاية الكلمة',
                                'whole_word': 'الكلمة كاملة',
                                'unclear': 'موضع غير محدد',
                              }[item['position_in_word']] ??
                              'موضع غير محدد';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.graphic_eq_rounded,
                                    color: Color(0xFF287D78),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$label · ${item['word_or_sound'] ?? ''}',
                                        style: const TextStyle(
                                          color: Color(0xFF203E3A),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (contextText.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'السياق: $contextText',
                                          style: const TextStyle(
                                            color: Color(0xFF526F6A),
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 3),
                                      Text(
                                        'الموضع: $position',
                                        style: const TextStyle(
                                          color: Color(0xFF7A8E8B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (confidence != null)
                                  Text(
                                    '${(confidence * 100).round()}%',
                                    style: const TextStyle(
                                      color: Color(0xFF7A8E8B),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: TaleeqTheme.borderSubtle),
        boxShadow: TaleeqTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _totalStuttering(double? value) {
    if (value == null) {
      return const Text(
        'غير متاح — لا يمكن تقدير النسبة بدقة من المحادثة وحدها.',
        style: TextStyle(color: Color(0xFF7A8E8B), height: 1.6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'نسبة التأتأة الكلية',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF203E3A),
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF006B63),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 11,
            backgroundColor: const Color(0xFFE8EEEB),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF5FAFA8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'النسبة المقدّرة للكلام المتأثر بالتأتأة.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF8A9694),
          ),
        ),
      ],
    );
  }

  Widget _metricRow(
    String title,
    double? value,
    IconData icon,
    Color color,
  ) {
    final safeValue = value?.clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF203E3A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value == null
                    ? 'غير متاح'
                    : '${value.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF203E3A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (safeValue != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (safeValue / 100).toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFFE8EEEB),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
        ],
      ),
    );
  }
}
