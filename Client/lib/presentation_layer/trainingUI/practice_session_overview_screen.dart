import 'package:flutter/material.dart';

import '../../models/technique_model.dart';
import '../../services/practice_session_service.dart';
import 'exercise_prep_screen_prepared.dart';
import '../exerciseUI/exercise_screen.dart';
import 'sessionResult/session_result_screen.dart';

import 'package:client/features/training/presentation/training_screen.dart';

class PracticeSessionOverviewScreen extends StatefulWidget {
  const PracticeSessionOverviewScreen({
    super.key,
    this.additionalSession = false,
    this.sessionId,
  });

  final bool additionalSession;
  final int? sessionId;

  @override
  State<PracticeSessionOverviewScreen> createState() =>
      _PracticeSessionOverviewScreenState();
}

class _PracticeSessionOverviewScreenState
    extends State<PracticeSessionOverviewScreen> {
  final _service = PracticeSessionService();

  late Future<Map<String, dynamic>> _sessionFuture;

  bool _openingExercise = false;

  static const Color _teal = Color(0xFF1F5F5A);
  static const Color _background = Color(0xFFFCFAF6);

  @override
  void initState() {
    super.initState();
    _sessionFuture = _prepareSession();
  }

  Future<Map<String, dynamic>> _prepareSession() {
    final sessionId = widget.sessionId;

    if (sessionId != null) {
      return _service.getSession(sessionId);
    }

    return _service.prepareToday(additionalSession: widget.additionalSession);
  }

  void _retry() {
    setState(() {
      _sessionFuture = _prepareSession();
    });
  }

  void _refreshSession(int sessionId) {
    if (!mounted) return;

    setState(() {
      _sessionFuture = _service.getSession(sessionId);
    });
  }

  String _exerciseType(String value) {
    return switch (value) {
      'Reading' => 'القراءة',
      'Picture Description' => 'وصف صورة',
      'Free Speech' => 'الحديث الحر',
      'Question & Answer' => 'سؤال وجواب',
      'Storytelling' => 'سرد قصة',
      _ => value,
    };
  }

  String _difficulty(String value) {
    return switch (value) {
      'Easy' => 'سهل',
      'Medium' => 'متوسط',
      'Hard' => 'متقدم',
      _ => value,
    };
  }

  String _statusLabel(String value) {
    return switch (value) {
      'completed' => 'مكتمل',
      'in_progress' => 'غير مكتمل',
      'pending' => 'لم يتم البدء',
      _ => value,
    };
  }

  void _showError(Object error) {
    if (!mounted) return;

    final message = error is PracticeSessionException
        ? error.message
        : 'حدث خطأ. يرجى المحاولة مجددًا.';

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openExercise(int sessionId, int sessionExerciseId) async {
    if (_openingExercise) return;

    setState(() {
      _openingExercise = true;
    });

    try {
      // Fetch the exercise and its recommended technique.
      final response = await _service.getSessionExercise(
        sessionId,
        sessionExerciseId,
      );

      if (!mounted) return;
      if (response['status'] == 'completed') {
        _refreshSession(sessionId);
        return;
      }

      // Completed exercises are allowed to open for review or repetition.
      final exerciseData = Map<String, dynamic>.from(
        response['exercise'] as Map,
      );

      final techniqueData = response['technique'];

      if (techniqueData is! Map) {
        throw const PracticeSessionException('تعذر تحميل التقنية الموصى بها.');
      }

      final recommendedTechnique = TechniqueModel.fromJson(
        Map<String, dynamic>.from(techniqueData),
      );

      // Open the preparation screen.
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (prepContext) => ExercisePrepScreen(
            exercise: ExerciseDetails.fromJson(exerciseData),
            recommendedTechniqueId: recommendedTechnique.id,
            onStart: (data) async {
              try {
                // Start or resume the selected exercise.
                final startedSession = await _service.startSession(
                  sessionId,
                  sessionExerciseId: sessionExerciseId,
                );

                if (!prepContext.mounted) return;

                final startedExerciseId =
                    startedSession['next_session_exercise_id'];

                if (startedExerciseId != sessionExerciseId) {
                  throw const PracticeSessionException(
                    'تعذر بدء التمرين المحدد.',
                  );
                }

                // Open the recording screen.
                final exerciseCompleted = await Navigator.of(prepContext)
                    .push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ExerciseScreen(
                          exercise: exerciseData,
                          technique: recommendedTechnique,
                          sessionExerciseId: sessionExerciseId,
                        ),
                      ),
                    );

                if (!prepContext.mounted) return;

                // Return to overview after successful submission or exit.
                if (exerciseCompleted == true) {
                  Navigator.of(prepContext).pop(true);
                } else if (exerciseCompleted == false) {
                  Navigator.of(prepContext).pop(false);
                }
              } catch (error) {
                if (!prepContext.mounted) return;

                final message = error is PracticeSessionException
                    ? error.message
                    : 'تعذر بدء التمرين. يرجى المحاولة مجددًا.';

                ScaffoldMessenger.of(prepContext)
                    .showSnackBar(SnackBar(content: Text(message)));
              }
            },
          ),
        ),
      );

      if (!mounted) return;

      // Reload the session to reflect the latest exercise statuses.
      _refreshSession(sessionId);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _openingExercise = false;
        });
      }
    }
  }

  // Open independent training.
  // Additional training does not affect personalized session progress.
  Future<void> _openAdditionalTraining() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('تدريبات إضافية'),
            backgroundColor: _background,
            foregroundColor: _teal,
          ),
          body: TrainingScreen(
            showBottomNav: false,
            onStartExercise: (selection) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('هذا النوع من التدريب غير متاح من هذه الشاشة.'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(int completed, int total) {
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تقدمك في الجلسة',
                style: TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '$completed من $total',
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6FA7A3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int sessionId) {
    final status = exercise['status']?.toString() ?? 'pending';
    final completed = status == 'completed';

    final sessionExerciseId = exercise['session_exercise_id'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: completed ? const Color(0xFFEAF4F2) : const Color(0xFFF3EADF),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        // Allow completed exercises to be opened again.
        enabled: !completed && !_openingExercise,
        onTap: completed || _openingExercise
            ? null
            : () => _openExercise(sessionId, sessionExerciseId),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0ECE9),
          foregroundColor: _teal,
          child: completed
              ? const Icon(Icons.check)
              : Text('${exercise['position']}'),
        ),
        title: Text(
          exercise['title']?.toString() ?? 'تمرين',
          style: const TextStyle(
            color: _teal,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_exerciseType(exercise['exercise_type']?.toString() ?? '')} · '
                '${_difficulty(exercise['difficulty']?.toString() ?? '')}',
              ),
              const SizedBox(height: 8),
              Text(
                _statusLabel(status),
                style: TextStyle(
                  color: completed
                      ? const Color(0xFF287D78)
                      : const Color(0xFF526B68),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: completed
            ? const Icon(Icons.check_circle, color: _teal)
            : const Icon(Icons.arrow_forward_ios, size: 18, color: _teal),
      ),
    );
  }

  Widget _buildAdditionalRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'تدريبات إضافية مقترحة',
          style: TextStyle(
            color: _teal,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'يمكنك استكشاف الألعاب التدريبية وسيناريوهات '
          'الحياة الواقعية للتدرب بشكل إضافي خارج جلستك المخصصة.',
          style: TextStyle(color: Color(0xFF526B68), height: 1.6),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openAdditionalTraining,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('استكشاف تدريبات إضافية'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: const BorderSide(color: _teal),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('جلستك التدريبية'),
        backgroundColor: _background,
        foregroundColor: _teal,
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _teal),
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;

              final message = error is PracticeSessionException
                  ? error.message
                  : 'تعذر تحميل الجلسة. يرجى المحاولة مجددًا.';

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _retry,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final session = snapshot.data!;
            final sessionId = session['session_id'] as int;

            final exercises =
                (session['exercises'] as List)
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList()
                  ..sort(
                    (a, b) =>
                        (a['position'] as int).compareTo(b['position'] as int),
                  );

            final completedCount = exercises
                .where((exercise) => exercise['status'] == 'completed')
                .length;

            final allCompleted =
                exercises.isNotEmpty && completedCount == exercises.length;

            return Stack(
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        allCompleted
                            ? 'أحسنت! أكملت جلستك التدريبية'
                            : '${exercises.length} تمارين مخصصة لك',
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        allCompleted
                            ? 'لقد أنهيت جميع تمارين هذه الجلسة.'
                            : 'تعرّف على التمارين المختارة لك وابدأ التدريب.',
                        style: const TextStyle(color: Color(0xFF526B68)),
                      ),
                      const SizedBox(height: 20),

                      _buildProgress(completedCount, exercises.length),

                      const SizedBox(height: 24),

                      const Text(
                        'تمارين الجلسة',
                        style: TextStyle(
                          color: _teal,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),

                      for (final exercise in exercises)
                        _buildExerciseCard(exercise, sessionId),

                      if (allCompleted) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF4F2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: _teal,
                                size: 40,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'تم إكمال الجلسة بنجاح!',
                                style: TextStyle(
                                  color: _teal,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SessionResultScreen(sessionId: sessionId),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'عرض نتيجة الجلسة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Optional training outside the session.
                      _buildAdditionalRecommendations(),
                    ],
                  ),
                ),

                if (_openingExercise)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
