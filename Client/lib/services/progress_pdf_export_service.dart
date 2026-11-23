
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/fluency_profile_data.dart';
import '../models/progress_assessment_model.dart';
import '../models/session_result_model.dart';
import 'exercise_api_service.dart';
import 'game_progress_api_service.dart';
import 'progress_service.dart';
import 'session_result_service.dart';

class ProgressPdfExportService {
  static const _teal = PdfColor(0.122, 0.373, 0.353);
  static const _dark = PdfColor(0.180, 0.227, 0.220);
  static const _muted = PdfColor(0.420, 0.494, 0.482);
  static const _border = PdfColor(0.910, 0.937, 0.937);
  static const _background = PdfColor(1.0, 0.988, 0.973);

  final _progress = ProgressService();
  final _sessions = SessionResultService();
  final _games = GameProgressApiService();
  final _exercises = ExerciseApiService();

  Future<Uint8List> generate() async {
    final history = await _progress.getAssessmentHistory();
    history.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    FluencyProfileData? latestAssessment;
    if (history.isNotEmpty) {
      latestAssessment = await _progress.getAssessmentDetails(history.first.assessmentId);
    }

    ProgressOverviewData overview = const ProgressOverviewData();
    try {
      overview = await _sessions.fetchOverview();
    } catch (_) {}

    SessionHistoryItem? latestSession;
    SessionResultData? sessionResult;
    try {
      final items = await _sessions.fetchHistory(limit: 1);
      if (items.isNotEmpty) {
        latestSession = items.first;
        try {
          sessionResult = await _sessions.fetchSessionResult(latestSession.sessionId);
        } catch (_) {}
      }
    } catch (_) {}

    final attempts = await _loadAttempts();
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

    final widgets = <pw.Widget>[
      _header(),
      _section('نظرة عامة'),
      pw.Row(children: [
        pw.Expanded(child: _metric('التقييمات', '${history.length}')),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _metric('محاولات التدريب', '${attempts.length}')),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _metric('آخر جلسة', latestSession?.totalScore?.toStringAsFixed(1) ?? '—')),
      ]),
      pw.SizedBox(height: 9),
      _card([
        _label('مخطط تطور نسبة التأتأة'),
        ..._trendRows(history, overview),
      ]),
      _section('أحدث تقييم'),
    ];

    if (latestAssessment == null) {
      widgets.add(_card([_mutedText('لا توجد تقييمات مكتملة حتى الآن.')]));
    } else {
      widgets.addAll(_assessmentWidgets(history.first, latestAssessment));
    }

    widgets.add(_section('آخر جلسة'));
    if (latestSession == null) {
      widgets.add(_card([_mutedText('لا توجد جلسات مكتملة حتى الآن.')]));
    } else {
      widgets.addAll(_sessionWidgets(latestSession, sessionResult));
    }

    widgets.add(_section('جميع محاولات التدريب والألعاب'));
    widgets.add(_mutedText('عدد المحاولات: ${attempts.length}'));
    if (attempts.isEmpty) {
      widgets.add(_card([_mutedText('لا توجد محاولات تدريب مسجلة حتى الآن.')]));
    } else {
      for (var i = 0; i < attempts.length; i++) {
        widgets.add(_attemptCard(attempts[i], i + 1));
      }
    }

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 34, 28, 42),
        textDirection: pw.TextDirection.rtl,
        buildBackground: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: _background),
        ),
      ),
      header: (_) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text('طليق • تقرير التقدم', style: pw.TextStyle(fontSize: 9, color: _muted)),
      ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('طليق • ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 9, color: _muted)),
      ),
      build: (_) => widgets,
    ));

    return doc.save();
  }

  Future<List<Map<String, dynamic>>> _loadAttempts() async {
    final all = <Map<String, dynamic>>[];
    try {
      final data = await _exercises.getAllAttempts();
      all.addAll(data.map((e) => {...e, '_source': 'تمرين كلام'}));
    } catch (_) {}
    try {
      final response = await _games.getDontSayItProgress();
      final raw = response['attempts'];
      if (raw is List) {
        all.addAll(raw.whereType<Map>().map((e) => {
          ...Map<String, dynamic>.from(e),
          '_source': 'لا تقولها',
          'exercise_title': 'لا تقولها: ${e['target_word'] ?? 'تحدي'}',
        }));
      }
    } catch (_) {}
    try {
      final response = await _games.getNamingChallengeAttempts();
      final raw = response['attempts'];
      if (raw is List) {
        all.addAll(raw.whereType<Map>().map((e) => {
          ...Map<String, dynamic>.from(e),
          '_source': 'تحدي التسمية',
          'exercise_title': 'تحدي التسمية: ${e['prompt'] ?? 'تحدي'}',
        }));
      }
    } catch (_) {}
    all.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return all;
  }

  pw.Widget _header() => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(18),
    margin: const pw.EdgeInsets.only(bottom: 12),
    decoration: pw.BoxDecoration(color: _teal, borderRadius: pw.BorderRadius.circular(15)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('تقرير التقدم', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      pw.SizedBox(height: 4),
      pw.Text('ملخص رحلتك في طليق', style: pw.TextStyle(fontSize: 11, color: PdfColor(0.812, 0.894, 0.882))),
      pw.SizedBox(height: 7),
      pw.Text('تاريخ التصدير: ${_date(DateTime.now().toIso8601String())}', style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
    ]),
  );

  pw.Widget _section(String title) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 13, bottom: 8),
    padding: const pw.EdgeInsets.only(right: 9, top: 4, bottom: 4),
    decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _teal, width: 3))),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _dark)),
  );

  pw.Widget _metric(String title, String value) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(11), border: pw.Border.all(color: _border)),
    child: pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _teal)),
      pw.SizedBox(height: 3),
      pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, color: _muted)),
    ]),
  );

  pw.Widget _card(List<pw.Widget> children) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: _border)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
  );

  pw.Widget _label(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 7),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _dark)),
  );

  pw.Widget _mutedText(String text) => pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _muted));

  List<pw.Widget> _trendRows(List<ProgressAssessment> history, ProgressOverviewData overview) {
    final points = <_Point>[
      ...history.reversed.map((e) => _Point(e.completedAt.toLocal(), 'التقييم • ${_date(e.completedAt.toIso8601String())}', e.overallStutteringPercent, _teal)),
      ...overview.sessionsSeries.map((e) => _Point(e.date, 'جلسة • ${_date(e.date.toIso8601String())}', e.stutteringPercent, const PdfColor(0.78, 0.50, 0.37))),
      ...overview.trainingSeries.map((e) => _Point(e.date, 'تدريب • ${_date(e.date.toIso8601String())}', e.stutteringPercent, const PdfColor(0.48, 0.62, 0.82))),
    ];
    if (points.isEmpty) return [_mutedText('لا توجد بيانات كافية لعرض التطور.')];
    points.sort((a, b) => a.date.compareTo(b.date));
    return points.map((p) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.SizedBox(width: 100, child: pw.Text(p.label, style: pw.TextStyle(fontSize: 8, color: _muted))),
        pw.Expanded(child: pw.Container(
          height: 6,
          alignment: pw.Alignment.centerRight,
          decoration: pw.BoxDecoration(color: _border, borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Container(width: 210 * (p.value.clamp(0, 100) / 100), height: 6, decoration: pw.BoxDecoration(color: p.color, borderRadius: pw.BorderRadius.circular(3))),
        )),
        pw.SizedBox(width: 7),
        pw.Text('${p.value.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 8, color: _dark)),
      ]),
    )).toList();
  }

  List<pw.Widget> _assessmentWidgets(ProgressAssessment assessment, FluencyProfileData data) => [
    _card([
      _row('تاريخ التقييم', _date(assessment.completedAt.toIso8601String())),
      _row('نسبة التأتأة الكلية', '${data.overallStutteringPercent.toStringAsFixed(1)}%'),
      _row('النمط الأكثر ظهورًا', data.primaryPatternArabic),
    ]),
    _card([
      _label('أنماط التأتأة'),
      _bar('التكرار', data.repetitionPercent),
      _bar('الإطالة', data.prolongationPercent),
      _bar('التوقف', data.blockPercent),
    ]),
    _card([
      _label('أداء المهام'),
      if (data.taskResults.isEmpty) _mutedText('لا توجد تفاصيل مهام متاحة.'),
      ...data.taskResults.map((t) => _row(_taskName(t.taskType), '${t.percent.toStringAsFixed(1)}% • ${_pattern(t.pattern)}')),
      if (data.speechEvents.isNotEmpty) _row('مواضع التأتأة', data.speechEvents.map((e) => e.wordOrSound).join('، ')),
    ]),
  ];

  List<pw.Widget> _sessionWidgets(SessionHistoryItem session, SessionResultData? result) {
    final out = <pw.Widget>[
      _card([
        _row('الجلسة', session.sequenceNumber == null ? 'جلسة تدريبية' : 'الجلسة ${session.sequenceNumber}'),
        _row('التاريخ', session.practiceDate ?? 'غير محدد'),
        _row('عدد التمارين', '${session.exerciseCount}'),
        _row('الدرجة', session.totalScore?.toStringAsFixed(1) ?? 'غير متاحة'),
      ]),
    ];
    if (result != null && result.ready) {
      out.add(_card([
        _label('تفاصيل نتيجة الجلسة'),
        _row('نسبة التأتأة', _percent(result.metrics.stuttering)),
        _row('التكرار', _percent(result.metrics.repetition)),
        _row('الإطالة', _percent(result.metrics.prolongation)),
        _row('التوقف', _percent(result.metrics.block)),
        _row('الطلاقة', _score(result.scores.fluency)),
        _row('الإيقاع', _score(result.scores.rhythm)),
        _row('التحكم بالسرعة', _score(result.scores.speedControl)),
        if (result.strength?.isNotEmpty == true) _row('نقطة قوة', result.strength!),
        if (result.improvement?.isNotEmpty == true) _row('نقطة للتحسين', result.improvement!),
        ...result.exercises.map((e) => _row(e.title, e.totalScore?.toStringAsFixed(1) ?? '—')),
      ]));
    }
    return out;
  }

  pw.Widget _attemptCard(Map<String, dynamic> item, int index) {
    final title = (item['exercise_title'] ?? item['title'] ?? item['exercise_name'] ?? item['prompt'] ?? item['target_word'] ?? 'محاولة تدريبية').toString();
    final source = (item['_source'] ?? item['exercise_type'] ?? 'تدريب').toString();
    final date = _date(item['created_at']?.toString());
    final duration = _int(item['duration_seconds']);
    final score = _scoreFromAttempt(item);
    final percent = _findPercent(item);
    return _card([
      pw.Row(children: [
        pw.Expanded(child: pw.Text('$index. $title', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _dark))),
        pw.Text(source, style: pw.TextStyle(fontSize: 8, color: _teal)),
      ]),
      pw.SizedBox(height: 5),
      pw.Wrap(spacing: 12, runSpacing: 3, children: [
        _smallDetail('التاريخ', date),
        if (duration != null) _smallDetail('المدة', '$duration ث'),
        if (score != null) _smallDetail('الدرجة', score.toStringAsFixed(1)),
        if (percent != null) _smallDetail('نسبة التأتأة', '${percent.toStringAsFixed(1)}%'),
      ]),
    ]);
  }

  pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 105, child: pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _muted))),
      pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 9, color: _dark))),
    ]),
  );

  pw.Widget _bar(String label, double value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _dark))),
        pw.Text('${value.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 9, color: _teal)),
      ]),
      pw.SizedBox(height: 4),
      pw.Container(height: 6, alignment: pw.Alignment.centerRight, decoration: pw.BoxDecoration(color: _border, borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Container(width: 250 * (value.clamp(0, 100) / 100), height: 6, decoration: pw.BoxDecoration(color: _teal, borderRadius: pw.BorderRadius.circular(3))),
      ),
    ]),
  );

  pw.Widget _smallDetail(String label, String value) => pw.Text('$label: $value', style: pw.TextStyle(fontSize: 8, color: _muted));

  String _date(String? raw) {
    final d = DateTime.tryParse(raw ?? '')?.toLocal();
    if (d == null) return 'غير محدد';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _percent(double? value) => value == null ? 'غير متاحة' : '${value.toStringAsFixed(1)}%';
  String _score(double? value) => value == null ? 'غير متاحة' : value.toStringAsFixed(1);
  int? _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  double? _scoreFromAttempt(Map<String, dynamic> item) {
    final scores = item['scores'];
    if (scores is Map && scores['total_score'] is num) return (scores['total_score'] as num).toDouble();
    final value = item['total_score'] ?? item['score'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? _findPercent(dynamic value, [int depth = 0]) {
    if (depth > 6 || value == null) return null;
    if (value is Map) {
      final direct = value['stuttering_percent'] ?? value['stuttering_percentage'];
      if (direct is num) return direct.toDouble();
      for (final key in const ['metrics', 'speech_analysis', 'analysis', 'result', 'data', 'overall_analysis']) {
        if (value[key] != null) {
          final found = _findPercent(value[key], depth + 1);
          if (found != null) return found;
        }
      }
      for (final entry in value.entries) {
        if (entry.value is Map || entry.value is List) {
          final found = _findPercent(entry.value, depth + 1);
          if (found != null) return found;
        }
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findPercent(child, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  String _taskName(String value) {
    switch (value.toLowerCase()) {
      case 'task_1':
      case 'reading': return 'القراءة بصوت عالٍ';
      case 'task_2':
      case 'picture_description': return 'وصف الصورة';
      case 'task_3':
      case 'spontaneous_speech': return 'التحدث العفوي';
      default: return value;
    }
  }

  String _pattern(String value) {
    switch (value.toLowerCase()) {
      case 'repetition': return 'التكرار';
      case 'prolongation': return 'الإطالة';
      case 'block': return 'التوقف';
      default: return value;
    }
  }
}

class _Point {
  const _Point(this.date, this.label, this.value, this.color);
  final DateTime date;
  final String label;
  final double value;
  final PdfColor color;
}
