
import 'package:flutter/material.dart';

/// واجهة تحليل التأتأة المشتركة بين ألعاب طليق.
class GameStutteringAnalysis {
  GameStutteringAnalysis._();

  static const Color teal = Color(0xFF1F5F5A);
  static const Color mint = Color(0xFF6FA7A3);
  static const Color coral = Color(0xFFD97757);
  static const Color background = Color(0xFFFFFBF6);
  static const Color border = Color(0xFFE5E8E4);

  /// تستقبل نتيجة speech_analysis من الـ Backend.
  static Future<bool> show({
    required BuildContext context,
    required dynamic speechAnalysis,
  }) async {
    if (speechAnalysis is! Map) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تحليل التأتأة غير متوفر لهذا التسجيل.'),
        ),
      );
      return false;
    }

    final analysis = Map<String, dynamic>.from(speechAnalysis);

    final returnToGame = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: background,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(dialogContext).height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(dialogContext),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      0,
                      18,
                      18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOverallCard(analysis),
                        const SizedBox(height: 16),
                        _buildPatternsCard(analysis),
                        const SizedBox(height: 16),
                        _buildSpeechEventsCard(analysis),
                        const SizedBox(height: 16),
                        _buildAdditionalMetricsCard(analysis),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'العودة إلى اللعبة',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return returnToGame ?? false;
  }

  // ------------------------------------------------------------
  // Header
  // ------------------------------------------------------------

static Widget _buildHeader(BuildContext context) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
  child: Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_rounded),
          color: teal,
          tooltip: 'رجوع إلى نتائج اللعبة',
        ),
      ),
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4F2),
          borderRadius: BorderRadius.circular(19),
        ),
        child: const Icon(
          Icons.analytics_outlined,
          color: teal,
          size: 32,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'تحليل التأتأة',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: teal,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'تحليل أنماط الكلام خلال هذه المحاولة',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          height: 1.5,
        ),
      ),
    ],
  ),
);

  // ------------------------------------------------------------
  // Overall stuttering
  // ------------------------------------------------------------

  static Widget _buildOverallCard(
    Map<String, dynamic> analysis,
  ) {
    final value = _readNumber(
      analysis['stuttering_percent'],
    );

    final hasValue = value != null;
    final percentage =
        (value ?? 0).clamp(0.0, 100.0).toDouble();

    return _sectionCard(
      title: 'نسبة التأتأة الكلية',
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  hasValue
                      ? 'مؤشر التأتأة في التسجيل'
                      : 'النسبة غير متوفرة',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ),
              if (hasValue)
                Text(
                  '${_formatNumber(percentage)}%',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: teal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: hasValue ? percentage / 100 : 0,
              minHeight: 10,
              backgroundColor: const Color(0xFFE8EEEC),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(mint),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            hasValue
                ? 'النسبة المقدّرة للكلام المتأثر بالتأتأة.'
                : 'لم يُرجع التحليل قيمة رقمية لهذا المؤشر.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Stuttering patterns
  // ------------------------------------------------------------

  static Widget _buildPatternsCard(
    Map<String, dynamic> analysis,
  ) {
    final patterns = <_PatternData>[
      _PatternData(
        title: 'التكرار',
        subtitle: 'Repetition',
        value: _readNumber(
          analysis['repetition_percent'],
        ),
        color: teal,
        icon: Icons.repeat_rounded,
      ),
      _PatternData(
        title: 'الإطالة',
        subtitle: 'Prolongation',
        value: _readNumber(
          analysis['prolongation_percent'],
        ),
        color: mint,
        icon: Icons.graphic_eq_rounded,
      ),
      _PatternData(
        title: 'التوقف',
        subtitle: 'Block',
        value: _readNumber(
          analysis['block_percent'],
        ),
        color: coral,
        icon: Icons.pause_circle_outline_rounded,
      ),
    ];

    return _sectionCard(
      title: 'أنماط التأتأة',
      icon: Icons.bar_chart_rounded,
      child: Column(
        children: [
          for (final pattern in patterns)
            _buildPatternRow(pattern),
          const SizedBox(height: 4),
          
        ],
      ),
    );
  }

  static Widget _buildPatternRow(
    _PatternData pattern,
  ) {
    final hasValue = pattern.value != null;
    final percentage =
        (pattern.value ?? 0).clamp(0.0, 100.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: pattern.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  pattern.icon,
                  color: pattern.color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pattern.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      pattern.subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                hasValue
                    ? '${_formatNumber(percentage)}%'
                    : 'غير متوفر',
                style: TextStyle(
                  color: pattern.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: hasValue ? percentage / 100 : 0,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDF0ED),
              valueColor: AlwaysStoppedAnimation<Color>(
                pattern.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Speech events: type + word/sound only
  // ------------------------------------------------------------

  static Widget _buildSpeechEventsCard(
    Map<String, dynamic> analysis,
  ) {
    final events = _readSpeechEvents(analysis);

    return _sectionCard(
      title: 'مواضع التأتأة',
      icon: Icons.record_voice_over_rounded,
      child: events.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'لم تُكتشف مواضع تأتأة محددة في هذا التسجيل.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < events.length; i++) ...[
                  _buildSpeechEvent(events[i]),
                  if (i < events.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  static List<Map<String, dynamic>> _readSpeechEvents(
    Map<String, dynamic> analysis,
  ) {
    final raw = analysis['speech_events'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map(
          (event) => Map<String, dynamic>.from(event),
        )
        .toList();
  }

  static Widget _buildSpeechEvent(
    Map<String, dynamic> event,
  ) {
    // أسماء الحقول المطابقة لنتيجة محلل الصوت.
    final type = _eventType(event['event_type']);
    final word = _firstText(event, [
      'word_or_sound',
      'word',
      'text',
    ]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _eventColor(type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _eventIcon(type),
              color: _eventColor(type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: teal,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  word.isNotEmpty ? word : 'لم يُحدد الصوت أو الكلمة',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _eventType(dynamic value) {
    final raw = value?.toString().toLowerCase().trim() ?? '';

    if (raw == 'repetition' ||
        raw == 'repeat' ||
        raw.contains('تكرار')) {
      return 'التكرار';
    }

    if (raw == 'prolongation' ||
        raw == 'prolong' ||
        raw.contains('إطالة')) {
      return 'الإطالة';
    }

    if (raw == 'block' ||
        raw.contains('انحباس') ||
        raw.contains('حبس')) {
      return 'الانحباس';
    }

    return 'حدث كلامي';
  }

  static Color _eventColor(String type) {
    switch (type) {
      case 'التكرار':
        return teal;
      case 'الإطالة':
        return mint;
      case 'الانحباس':
        return coral;
      default:
        return Colors.blueGrey;
    }
  }

  static IconData _eventIcon(String type) {
    switch (type) {
      case 'التكرار':
        return Icons.repeat_rounded;
      case 'الإطالة':
        return Icons.graphic_eq_rounded;
      case 'الانحباس':
        return Icons.pause_circle_outline_rounded;
      default:
        return Icons.record_voice_over_rounded;
    }
  }

  // ------------------------------------------------------------
  // Additional metrics
  // ------------------------------------------------------------

  static Widget _buildAdditionalMetricsCard(
    Map<String, dynamic> analysis,
  ) {
    final rate = _readNumber(
      analysis['speaking_rate_wpm'],
    );

    final speakingRateScore = _readNumber(
      analysis['speaking_rate'],
    );

    final timingPacing = _readNumber(
      analysis['timing_pacing'],
    );

    final metrics = <_MetricData>[];

    if (rate != null && rate >= 0) {
      // تحويل الكلمات في الدقيقة إلى تقدير الكلمات في 10 ثوانٍ.
      final wordsPerTenSeconds = rate / 6;

      metrics.add(
        _MetricData(
          title: 'معدل الكلام خلال 10 ثوانٍ',
          value: '${_formatNumber(wordsPerTenSeconds)} كلمة تقريبًا',
          icon: Icons.speed_rounded,
        ),
      );
    }

    if (speakingRateScore != null) {
      metrics.add(
        _MetricData(
          title: 'ملاءمة وثبات سرعة الكلام',
          value: '${_formatNumber(speakingRateScore)} / 100',
          icon: Icons.trending_up_rounded,
        ),
      );
    }

    if (timingPacing != null) {
      metrics.add(
        _MetricData(
          title: 'التوقيت وتدفق الكلام',
          value: '${_formatNumber(timingPacing)} / 100',
          icon: Icons.timeline_rounded,
        ),
      );
    }

    return _sectionCard(
      title: 'مؤشرات إضافية',
      icon: Icons.tune_rounded,
      child: metrics.isEmpty
          ? Text(
              'لا توجد مؤشرات إضافية في نتيجة التحليل.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < metrics.length; i++) ...[
                  _buildMetricRow(metrics[i]),
                  if (i < metrics.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  static Widget _buildMetricRow(
    _MetricData metric,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F6),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: teal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Shared UI helpers
  // ------------------------------------------------------------

  static Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: teal, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  static String _firstText(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];

      if (value == null || value is Map || value is List) {
        continue;
      }

      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return '';
  }

  static double? _readNumber(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(
        value.trim().replaceAll('%', ''),
      );
    }

    return null;
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}

class _PatternData {
  const _PatternData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final double? value;
  final Color color;
  final IconData icon;
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}
