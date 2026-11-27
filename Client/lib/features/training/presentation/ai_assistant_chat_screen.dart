import 'package:flutter/material.dart';

import 'theme/training_theme.dart';
import 'widgets/ai_exercise_recommendation_card.dart';
import '../data/ai_assistant_service.dart';

import '../data/models/training_models.dart';
import '../data/training_api_service.dart';

import '../data/training_repository.dart';
import '../../../presentation_layer/trainingUI/exercise_prep_screen_prepared.dart';

import 'package:client/presentation_layer/exerciseUI/exercise_screen.dart';
import 'package:client/services/technique_service.dart';
import 'package:client/presentation_layer/error_snackbar.dart';

import '../../../presentation_layer/trainingUI/Games/dont_say_it_screen.dart';
import '../../../presentation_layer/trainingUI/Games/naming_challenge_screen.dart';

import 'package:client/models/scenario_model.dart';
import 'package:client/services/scenario_api_service.dart';
import 'package:client/presentation_layer/trainingUI/scenario_instructions_screen.dart';

class AiAssistantChatScreen extends StatefulWidget {
  const AiAssistantChatScreen({super.key});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiAssistantService _aiAssistantService = const AiAssistantService();
  final TrainingApiService _trainingApiService = const TrainingApiService();
  final ScenarioApiService _scenarioApiService = ScenarioApiService();

  bool _isLoading = false;
  bool _isStartingExercise = false;
  Map<String, dynamic>? _loadingRecommendation;
  bool _hasMessage = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'content':
          'أهلًا بك في مساعد طليق! 🌿\n'
          'أخبرني، ما الصعوبات التي تواجهها في الكلام أو ما الجوانب التي ترغب في تحسينها؟',
    },
  ];
  final List<Map<String, String>> _apiMessages = [];
  Map<String, dynamic>? _recommendedExercise;
  String? _recommendedScenarioName;

  Future<void> _sendMessage({
    String? apiMessage,
    bool explanationOnly = false,
  }) async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isLoading || _isStartingExercise) return;

    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _apiMessages.add({'role': 'user', 'content': apiMessage ?? message});
      _isLoading = true;
    });

    _messageController.clear();

    setState(() {
      _hasMessage = false;
    });

    _scrollToBottom();

    try {
      final response = await _aiAssistantService.sendMessage(_apiMessages);

      if (!mounted) return;
      final recommendation =
          response['recommended_exercise'] as Map<String, dynamic>?;
      setState(() {
        final reply = response['reply'] as String;

        if (recommendation == null || explanationOnly) {
          _messages.add({'role': 'assistant', 'content': reply});
        }

        _apiMessages.add({
          'role': 'assistant',
          'content': recommendation == null || explanationOnly
              ? reply
              : '$reply\n'
                    'تفاصيل التوصية: '
                    'الفئة ${recommendation['category']}، '
                    'النوع ${recommendation['exercise_type']}، '
                    'المستوى ${recommendation['difficulty']}، '
                    'معرّف السيناريو ${recommendation['scenario_id']}.',
        });
        if (recommendation != null && !explanationOnly) {
          _recommendedExercise = recommendation;
          _recommendedScenarioName = null;

          _messages.add({
            'role': 'recommendation',
            'recommendation': Map<String, dynamic>.from(recommendation),
          });
        }

        _isLoading = false;
      });
      if (recommendation != null && recommendation['category'] == 'scenarios') {
        try {
          await _loadRecommendedScenarioName(recommendation);
        } catch (error) {
          debugPrint('Failed to load scenario name: $error');
        }
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _apiMessages.removeLast();
        _messages.removeLast();
      });

      _messageController.text = message;

      ErrorSnackBar.show(context, 'تعذر إرسال الرسالة. حاول مرة أخرى.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getExerciseName(String type) {
    const names = {
      'Reading': 'القراءة',
      'Picture Description': 'وصف الصورة',
      'Question & Answer': 'سؤال وجواب',
      'Storytelling': 'سرد القصص',
      'Free Speech': 'التحدث الحر',
      'countingChallenge': 'تحدي التعداد',
      'dontSayIt': 'لا تقولها',
      'real_life_scenarios': 'سيناريو من الحياة الواقعية',
    };

    return names[type] ?? type;
  }

  ExerciseSelection _getRecommendedSelection(
    Map<String, dynamic> recommendation,
    TrainingExercise exercise,
  ) {
    final type = ExerciseTypeParsing.fromAiValue(
      recommendation['exercise_type'] as String,
    );

    final difficulty = DifficultyParsing.fromAiValue(
      recommendation['difficulty'] as String,
    );

    if (exercise.type != type) {
      throw ArgumentError('Exercise type does not match recommendation');
    }

    return ExerciseSelection(exercise: exercise, difficulty: difficulty);
  }

  Future<TrainingExercise> _findRecommendedExercise(ExerciseType type) async {
    final categories = await const LocalTrainingRepository().fetchCategories();

    for (final category in categories) {
      for (final exercise in category.exercises) {
        if (exercise.type == type) {
          return exercise;
        }
      }
    }

    throw StateError('Recommended exercise not found: $type');
  }

  Future<void> _startRecommendedSpeechExercise(
    Map<String, dynamic> recommendation,
  ) async {
    if (_isStartingExercise) return;

    setState(() {
      _isStartingExercise = true;
      _loadingRecommendation = recommendation;
    });
    try {
      final type = ExerciseTypeParsing.fromAiValue(
        recommendation['exercise_type'] as String,
      );

      final exercise = await _findRecommendedExercise(type);

      final selection = _getRecommendedSelection(recommendation, exercise);

      final exerciseData = await _trainingApiService.fetchRandomExercise(
        selection,
      );

      if (!mounted) return;

      setState(() {
        _isStartingExercise = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExercisePrepScreen(
            exercise: ExerciseDetails.fromJson(exerciseData),
            onStart: (data) async {
              final techniqueId = data.techniqueId;

              final selectedTechnique = techniqueId == null
                  ? null
                  : await TechniqueService().getTechnique(techniqueId);

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
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingExercise = false;
          _loadingRecommendation = null;
        });
      }
    }
  }

  Future<void> _startRecommendedGame(
    Map<String, dynamic> recommendation,
  ) async {
    if (_isStartingExercise) return;

    setState(() {
      _isStartingExercise = true;
      _loadingRecommendation = recommendation;
    });
    try {
      final type = ExerciseTypeParsing.fromAiValue(
        recommendation['exercise_type'] as String,
      );

      final difficulty = DifficultyParsing.fromAiValue(
        recommendation['difficulty'] as String,
      );

      if (!mounted) return;

      switch (type) {
        case ExerciseType.countingChallenge:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NamingChallengeScreen(difficulty: difficulty.id),
            ),
          );
          break;

        case ExerciseType.dontSayIt:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DontSayItScreen(difficulty: difficulty.id),
            ),
          );
          break;

        default:
          throw ArgumentError('Unsupported game type: $type');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingExercise = false;
          _loadingRecommendation = null;
        });
      }
    }
  }

  Future<ScenarioModel> _findRecommendedScenario(String scenarioId) async {
    final scenarios = await _scenarioApiService.getScenarios();

    for (final scenario in scenarios) {
      if (scenario.id == scenarioId) {
        return scenario;
      }
    }

    throw StateError('Recommended scenario not found: $scenarioId');
  }

  Future<void> _loadRecommendedScenarioName(
    Map<String, dynamic> recommendation,
  ) async {
    final scenarioId = recommendation['scenario_id'] as String;

    final scenario = await _findRecommendedScenario(scenarioId);

    if (!mounted ||
        _recommendedExercise?['category'] != 'scenarios' ||
        _recommendedExercise?['scenario_id'] != scenarioId) {
      return;
    }

    setState(() {
      _recommendedScenarioName = scenario.name;

      for (final message in _messages) {
        if (message['role'] == 'recommendation' &&
            message['recommendation']['scenario_id'] == scenarioId) {
          message['scenarioName'] = scenario.name;
        }
      }
    });
  }

  Future<void> _startRecommendedScenario(
    Map<String, dynamic> recommendation,
  ) async {
    if (_isStartingExercise) return;

    setState(() {
      _isStartingExercise = true;
      _loadingRecommendation = recommendation;
    });
    try {
      final scenarioId = recommendation['scenario_id'] as String;

      final difficulty = DifficultyParsing.fromAiValue(
        recommendation['difficulty'] as String,
      );

      final scenario = await _findRecommendedScenario(scenarioId);

      final difficulties = await _scenarioApiService.getScenarioDifficulties(
        scenario.id,
      );

      final selectedDifficulty = difficulties.firstWhere(
        (item) => item.difficulty.toLowerCase() == difficulty.id,
        orElse: () => throw StateError(
          'Recommended difficulty is not available for this scenario.',
        ),
      );

      final attempt = await _scenarioApiService.startScenario(
        scenarioId: scenario.id,
        difficultyId: selectedDifficulty.id,
      );

      if (!mounted) return;
      setState(() {
        _isStartingExercise = false;
      });
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScenarioInstructionsScreen(
            attemptId: attempt.id,
            scenario: scenario,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingExercise = false;
          _loadingRecommendation = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TrainingColors.background,
        appBar: AppBar(
          backgroundColor: TrainingColors.background,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'مساعد طليق',
            style: TrainingText.categoryTitle.copyWith(
              color: TrainingColors.primaryDark,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: _scrollController,
            children: [
              for (final message in _messages) ...[
                if (message['role'] == 'recommendation')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AiExerciseRecommendationCard(
                        exerciseName:
                            message['scenarioName'] as String? ??
                            _getExerciseName(
                              message['recommendation']['exercise_type']
                                  as String,
                            ),
                        description:
                            message['recommendation']['reason'] as String,
                        isLoading:
                            _isStartingExercise &&
                            identical(
                              _loadingRecommendation,
                              message['recommendation'],
                            ),
                        isDisabled: _isLoading || _isStartingExercise,
                        onStart: () async {
                          final recommendation =
                              message['recommendation'] as Map<String, dynamic>;

                          try {
                            switch (recommendation['category']) {
                              case 'speech':
                                await _startRecommendedSpeechExercise(
                                  recommendation,
                                );
                                break;

                              case 'games':
                                await _startRecommendedGame(recommendation);
                                break;

                              case 'scenarios':
                                await _startRecommendedScenario(recommendation);
                                break;
                            }
                          } catch (error) {
                            debugPrint(
                              'Failed to open recommended exercise: $error',
                            );

                            if (!mounted) return;

                            ErrorSnackBar.show(
                              context,
                              'تعذر بدء التمرين، حاول مرة أخرى.',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          ActionChip(
                            avatar: Icon(
                              Icons.info_outline_rounded,
                              color: TrainingColors.primaryDark,
                              size: 19,
                            ),
                            label: const Text('لماذا هذا التمرين؟'),
                            labelStyle: TrainingText.body.copyWith(
                              color: TrainingColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: TrainingColors.mint,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            onPressed: _isLoading || _isStartingExercise
                                ? null
                                : () {
                                    final recommendation =
                                        message['recommendation']
                                            as Map<String, dynamic>;

                                    _messageController.text =
                                        'لماذا اخترت لي هذا التمرين؟';

                                    _sendMessage(
                                      explanationOnly: true,
                                      apiMessage:
                                          'اشرح لي لماذا اخترت لي هذا التمرين تحديدًا، '
                                          'وكيف يساعدني في تحسين طلاقة الكلام. '
                                          'التمرين: ${recommendation['exercise_type']}، '
                                          'المستوى: ${recommendation['difficulty']}.',
                                    );
                                  },
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.autorenew_rounded,
                              color: TrainingColors.primaryDark,
                              size: 19,
                            ),
                            label: const Text('اقترح تمرينًا آخر'),
                            labelStyle: TrainingText.body.copyWith(
                              color: TrainingColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: TrainingColors.mint,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            onPressed: _isLoading || _isStartingExercise
                                ? null
                                : () {
                                    final previous =
                                        message['recommendation']
                                            as Map<String, dynamic>;

                                    _messageController.text =
                                        'اقترح لي تمرينًا آخر';

                                    _sendMessage(
                                      apiMessage:
                                          'اقترح لي تمرينًا آخر مناسبًا ومختلفًا عن السابق. '
                                          'التوصية السابقة كانت: '
                                          'الفئة ${previous['category']}، '
                                          'النوع ${previous['exercise_type']}، '
                                          'المستوى ${previous['difficulty']}. '
                                          '${previous['category'] == 'scenarios' ? 'معرّف السيناريو السابق: ${previous['scenario_id']}.' : ''}',
                                    );
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                if (message['role'] != 'recommendation')
                  Align(
                    alignment: message['role'] == 'user'
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: message['role'] == 'user'
                            ? TrainingColors.primary
                            : TrainingColors.mint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        message['content'] ?? '',
                        textDirection: TextDirection.rtl,
                        style: TrainingText.body.copyWith(
                          color: message['role'] == 'user'
                              ? Colors.white
                              : TrainingColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
              ],
              if (_isLoading) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: TrainingColors.mint,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TrainingColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
  child: Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      16 + MediaQuery.of(context).viewInsets.bottom,
    ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (value) {
                      setState(() {
                        _hasMessage = value.trim().isNotEmpty;
                      });
                    },
                    textDirection: TextDirection.rtl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      hintStyle: TrainingText.body,
                      filled: true,
                      fillColor: TrainingColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: !_hasMessage || _isLoading || _isStartingExercise
                      ? null
                      : () => _sendMessage(),
                  style: IconButton.styleFrom(
                    backgroundColor: TrainingColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
