import 'package:flutter/material.dart';

import '../data/models/training_models.dart';
import '../data/training_repository.dart';
import '../data/training_api_service.dart';
import '../logic/training_controller.dart';
import 'theme/training_theme.dart';
import 'widgets/taleeq_bottom_nav.dart';
import 'widgets/taleeq_svg_icon.dart';
import 'widgets/training_category_card.dart';
import 'widgets/training_exercise_card.dart';
import '../../../presentation_layer/trainingUI/exercise_prep_screen_prepared.dart';
import 'package:client/presentation_layer/exerciseUI/exercise_screen.dart';
import 'package:client/services/technique_service.dart';

// TODO (Integration):
// Connect this callback to the Instructions screen.
// Pass the selected exercise data (id, type, title,
// instructions, difficulty, and content).
// Do not mark the exercise as completed here.
// Completion must happen after the user finishes the exercise.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    required this.onStartExercise,
    this.repository,
    this.onBack,
    this.showBottomNav = true,
    this.onTabSelected,
    this.onExerciseFetched,
  });

  final ValueChanged<ExerciseSelection> onStartExercise;

  /// Receives the exercise returned by FastAPI.
  final ValueChanged<Map<String, dynamic>>? onExerciseFetched;

  final TrainingRepository? repository;
  final VoidCallback? onBack;
  final bool showBottomNav;
  final ValueChanged<int>? onTabSelected;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late final TrainingController _controller;

  final TrainingApiService _apiService = const TrainingApiService();

  bool _isStartingExercise = false;

  @override
  void initState() {
    super.initState();

    _controller = TrainingController(
      repository: widget.repository ?? const LocalTrainingRepository(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _usesSpeechApi(ExerciseType type) {
    switch (type) {
      case ExerciseType.reading:
      case ExerciseType.pictureDescription:
      case ExerciseType.questionAnswer:
      case ExerciseType.storytelling:
      case ExerciseType.freeSpeech:
        return true;

      case ExerciseType.realLifeScenarios:
      case ExerciseType.wordLetterChallenge:
      case ExerciseType.sentenceBuilding:
      case ExerciseType.dualTask:
        return false;
    }
  }

  Future<void> _startExercise(TrainingExercise exercise) async {
    if (_isStartingExercise) return;

    final selection = _controller.selectionFor(exercise);

    // Other categories are handled by their own exercise flows.
    if (!_usesSpeechApi(selection.type)) {
      widget.onStartExercise(selection);
      return;
    }

    setState(() {
      _isStartingExercise = true;
    });

    try {
      final exerciseData = await _apiService.fetchRandomExercise(selection);

      if (!mounted) return;

      // Notify the parent that exercise data has been fetched.
      widget.onExerciseFetched?.call(exerciseData);

      // Navigate to Exercise Prep with the real exercise data.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExercisePrepScreen(
            exercise: ExerciseDetails.fromJson(exerciseData),
            onStart: (data) async {
              // TODO: Connect to Latifah's Exercise Execution screen.
            try {

              debugPrint('Exercise ID: ${data.exerciseId}');
              debugPrint('Exercise Type: ${data.exercise.type}');
              debugPrint('Technique ID: ${data.techniqueId}');
              final selectedTechnique =
                  await TechniqueService().getTechnique(data.techniqueId);

              if (!context.mounted) return;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExerciseScreen(
                    exercise: exerciseData,
                    technique: selectedTechnique,
                  ),
                ),
              );
            } catch (error) {
              debugPrint('Failed to open exercise: $error');
            }

            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error), textAlign: TextAlign.center),
          backgroundColor: const Color(0xFFB55252),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingExercise = false;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString();

    if (message.contains('Please log in')) {
      return 'يرجى تسجيل الدخول أولًا';
    }

    if (message.contains('session has expired')) {
      return 'انتهت جلسة تسجيل الدخول، يرجى تسجيل الدخول مجددًا';
    }

    if (message.contains('No exercises are available')) {
      return 'لا توجد تمارين متاحة لهذا النوع والمستوى حاليًا';
    }

    if (message.contains('Unsupported')) {
      return 'هذا النوع من التمارين غير متاح حاليًا';
    }

    return 'تعذر تحميل التمرين. تأكدي من تشغيل السيرفر وحاولي مجددًا';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TrainingColors.background,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: TrainingColors.primary,
                      ),
                    );
                  }

                  if (_controller.error != null) {
                    return _ErrorView(onRetry: _controller.load);
                  }

                  return _buildContent();
                },
              ),

              if (_isStartingExercise)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: TrainingColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: widget.showBottomNav
            ? TaleeqBottomNav(
                currentIndex: 1,
                onTabSelected: widget.onTabSelected,
              )
            : null,
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _BackButton(
                onTap: widget.onBack ?? () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 14),
            Text('التدريب', style: TrainingText.screenTitle),
            const SizedBox(height: 4),
            Text(
              'تمارين مخصصة بناءً على ملف طلاقتك',
              style: TrainingText.screenSubtitle,
            ),
            const SizedBox(height: 14),

            for (final category in _controller.categories) ...[
              TrainingCategoryCard(
                key: ValueKey(category.id),
                category: category,
                isExpanded: _controller.isExpanded(category.id),
                onToggle: () => _controller.toggleCategory(category.id),
                exercises: [
                  for (final e in category.exercises)
                    TrainingExerciseCard(
                      key: ValueKey(e.id),
                      exercise: e,
                      difficulty: _controller.difficultyOf(e),
                      isDropdownOpen: _controller.isDropdownOpen(e.id),
                      onToggleDropdown: () => _controller.toggleDropdown(e),
                      onDifficultySelected: (d) =>
                          _controller.selectDifficulty(e, d),
                      onStart: () => _startExercise(e),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'رجوع',
      child: Material(
        color: TrainingColors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(child: TaleeqSvgIcon(TaleeqIcons.chevronRight)),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('تعذّر تحميل التمارين', style: TrainingText.categoryTitle),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text('إعادة المحاولة', style: TrainingText.exerciseTitle),
          ),
        ],
      ),
    );
  }
}
