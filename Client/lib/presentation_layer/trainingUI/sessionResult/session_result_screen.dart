import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/session_result_model.dart';
import '../../../services/practice_session_service.dart'
    show PracticeSessionException;
import '../../../services/session_result_service.dart';
import '../../widgets/main_navigation_screen.dart';
import 'performance_details_sheet.dart';
import 'session_result_widgets.dart';

/// Screen 2: result of the whole session.
///
/// While some exercises are still being analyzed the backend answers with
/// status "pending"; this screen then polls the same endpoint.
class SessionResultScreen extends StatefulWidget {
  const SessionResultScreen({
    super.key,
    required this.sessionId,
    this.fromHistory = false,
  });

  final int sessionId;

  /// True when opened from the sessions list in the Progress tab: the screen
  /// then shows a back arrow and "إنهاء" returns to that list instead of
  /// going home.
  final bool fromHistory;

  @override
  State<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends State<SessionResultScreen> {
  static const int _maxPolls = 20;
  static const Duration _pollEvery = Duration(seconds: 3);

  final _service = SessionResultService();

  SessionResultData? _data;
  String? _error;
  bool _gaveUp = false;
  int _polls = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();

    try {
      final data = await _service.fetchSessionResult(widget.sessionId);

      if (!mounted) return;

      setState(() {
        _data = data;
        _error = null;
        _gaveUp = false;
      });

      if (!data.ready) {
        if (_polls < _maxPolls) {
          _polls++;
          _timer = Timer(_pollEvery, _load);
        } else {
          setState(() => _gaveUp = true);
        }
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error is PracticeSessionException
            ? error.message
            : 'تعذر تحميل النتيجة. يرجى المحاولة مجددًا.';
      });
    }
  }

  void _retry() {
    setState(() {
      _data = null;
      _error = null;
      _gaveUp = false;
      _polls = 0;
    });
    _load();
  }

  String _subtitle(SessionResultData data) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final label = data.practiceDate == today
        ? 'جلسة اليوم'
        : (data.practiceDate ?? 'جلسة تدريبية');

    return '${data.exerciseCount} تمارين · $label';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResultColors.background,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ResultErrorView(message: _error!, onRetry: _retry);
    }

    final data = _data;

    if (data == null || !data.ready) {
      if (_gaveUp) {
        return ResultErrorView(
          message: 'نتيجة الجلسة ما زالت قيد التجهيز. حاول مجددًا بعد قليل.',
          onRetry: _retry,
        );
      }

      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: ResultColors.teal),
            SizedBox(height: 16),
            Text(
              'جاري تجهيز نتيجتك...',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15,
                color: ResultColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (widget.fromHistory)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: IconButton(
                tooltip: 'رجوع',
                icon: const Icon(
                  Icons.arrow_back,
                  color: ResultColors.text,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              widget.fromHistory ? 8 : 32,
              20,
              12,
            ),
            child: Column(
              children: [
                const ResultCheckBadge(),
                const SizedBox(height: 22),
                const Text(
                  'أحسنت، أكملت الجلسة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: ResultColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(data),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: ResultColors.muted,
                  ),
                ),
                const SizedBox(height: 14),
                ResultSummaryCard(
                  title: 'درجتك الإجمالية للجلسة',
                  score: data.scores.total,
                  scoreChange: data.scoreChange,
                  strength: data.strength,
                  improvement: data.improvement,
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'نتائج التمارين ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ResultColors.text,
                          ),
                        ),
                        TextSpan(
                          text: '· اضغط على تمرين لتشوف نتيجته',
                          style: TextStyle(
                            fontSize: 12,
                            color: ResultColors.muted,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(fontFamily: 'Tajawal'),
                  ),
                ),
                const SizedBox(height: 10),
                for (final exercise in data.exercises) ...[
                  _ExerciseRow(
                    key: ValueKey('exercise-${exercise.sessionExerciseId}'),
                    session: data,
                    exercise: exercise,
                    service: _service,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            children: [
              ResultPrimaryButton(
                label: 'عرض تفاصيل الأداء',
                icon: Icons.bar_chart_rounded,
                onPressed: () =>
                    showPerformanceDetailsSheet(context, session: data),
              ),
              ResultTextButton(
                label: 'إنهاء',
                onPressed: () {
                  if (widget.fromHistory) {
                    Navigator.of(context).pop();
                    return;
                  }

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MainNavigationScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Accordion row: tapping loads and shows the exercise's own feedback.
class _ExerciseRow extends StatefulWidget {
  const _ExerciseRow({
    super.key,
    required this.session,
    required this.exercise,
    required this.service,
  });

  final SessionResultData session;
  final SessionExerciseSummary exercise;
  final SessionResultService service;

  @override
  State<_ExerciseRow> createState() => _ExerciseRowState();
}

class _ExerciseRowState extends State<_ExerciseRow> {
  bool _open = false;
  bool _loading = false;
  String? _error;
  ExerciseResultData? _detail;

  Future<void> _toggle() async {
    setState(() => _open = !_open);

    if (_open && _detail == null && !_loading) {
      await _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await widget.service.fetchExerciseResult(
        widget.session.sessionId,
        widget.exercise.sessionExerciseId,
      );

      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PracticeSessionException
            ? error.message
            : 'تعذر تحميل نتيجة التمرين.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final score = exercise.totalScore;

    return ResultCard(
      padding: EdgeInsets.zero,
      borderColor: _open ? ResultColors.teal : ResultColors.border,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.title,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ResultColors.text,
                      ),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      formatPercent(score),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ResultColors.tealDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.chevron_left_rounded,
                    size: 24,
                    color: ResultColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResultProgressBar(
                    fraction: (score ?? 0) / 100,
                    color: ResultColors.teal,
                    height: 8,
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: ResultColors.teal,
                          ),
                        ),
                      ),
                    )
                  else if (_error != null)
                    ResultErrorView(message: _error!, onRetry: _fetch)
                  else if (_detail != null)
                    ResultFeedbackText(
                      strength: _detail!.strength,
                      improvement: _detail!.improvement,
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => showPerformanceDetailsSheet(
                        context,
                        session: widget.session,
                        initialExerciseId: exercise.sessionExerciseId,
                      ),
                      icon: const Icon(Icons.bar_chart_rounded, size: 20),
                      label: const Text(
                        'عرض التفاصيل',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ResultColors.tealDark,
                        side: const BorderSide(color: ResultColors.teal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
