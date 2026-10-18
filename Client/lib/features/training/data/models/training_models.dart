import 'package:flutter/foundation.dart';

/// Difficulty levels. [id] is the value to store / send to the backend.
enum Difficulty {
  easy('easy', 'سهل', 1),
  medium('medium', 'متوسط', 2),
  hard('hard', 'متقدم', 3);

  const Difficulty(this.id, this.labelAr, this.bars);
  final String id;
  final String labelAr;

  /// Number of filled bars in the difficulty indicator (1..3).
  final int bars;
}

/// The nine exercise types. [id] is the stable key used by the backend.
enum ExerciseType {
  reading('reading'),
  pictureDescription('picture_description'),
  questionAnswer('question_answer'),
  storytelling('storytelling'),
  freeSpeech('free_speech'),
  realLifeScenarios('real_life_scenarios'),
  // Speaking games
  countingChallenge('counting_challenge'),
  dontSayIt('dont_say_it');

  const ExerciseType(this.id);
  final String id;
}

/// Drives the category icon (and its background colour) in the UI.
enum TrainingCategoryKind { speechPractice, realLifeScenarios, speakingGames }

@immutable
class TrainingExercise {
  const TrainingExercise({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.durationMinutes,
    this.durationSeconds,
    this.defaultDifficulty = Difficulty.easy,
  });

  final int? durationSeconds;

  final String id;
  final ExerciseType type;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;

  /// Fixed by the system. The user can never change it.
  final int durationMinutes;
  final Difficulty defaultDifficulty;
}

@immutable
class TrainingCategory {
  const TrainingCategory({
    required this.id,
    required this.kind,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.exercises,
  });

  final String id;
  final TrainingCategoryKind kind;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final List<TrainingExercise> exercises;
}

/// What the next page (Instructions) receives when "ابدأ التمرين" is pressed.
@immutable
class ExerciseSelection {
  const ExerciseSelection({required this.exercise, required this.difficulty});

  final TrainingExercise exercise;
  final Difficulty difficulty;

  ExerciseType get type => exercise.type;
  int get durationMinutes => exercise.durationMinutes;
}
