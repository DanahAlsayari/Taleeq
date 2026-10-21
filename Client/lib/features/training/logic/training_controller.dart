import 'package:flutter/foundation.dart';

import '../data/models/training_models.dart';
import '../data/training_repository.dart';

/// Holds the Training page state.
///
/// - All categories start collapsed.
/// - Only one category can be expanded at a time.
/// - Selected difficulties are preserved when categories collapse.
/// - Only one difficulty dropdown can be open at a time.
class TrainingController extends ChangeNotifier {
  TrainingController({
    required this._repository,
  });

  final TrainingRepository _repository;

  List<TrainingCategory> _categories = const [];

  bool _isLoading = true;
  Object? _error;

  // All categories are collapsed by default.
  String? _expandedCategoryId;

  String? _openDropdownExerciseId;

  final Map<String, Difficulty> _selected = {};

  bool _disposed = false;

  List<TrainingCategory> get categories => _categories;

  bool get isLoading => _isLoading;

  Object? get error => _error;

  bool isExpanded(String categoryId) =>
      _expandedCategoryId == categoryId;

  bool isDropdownOpen(String exerciseId) =>
      _openDropdownExerciseId == exerciseId;

  Difficulty difficultyOf(TrainingExercise exercise) =>
      _selected[exercise.id] ?? Difficulty.easy;

  ExerciseSelection selectionFor(TrainingExercise exercise) =>
      ExerciseSelection(
        exercise: exercise,
        difficulty: difficultyOf(exercise),
      );

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      _categories = await _repository.fetchCategories();

      // Keep all categories collapsed when the page first loads.
      // Do not automatically expand the first category.
    } catch (error) {
      _error = error;
    }

    _isLoading = false;
    _notify();
  }

  /// Opens one category and closes the previously expanded category.
  /// Tapping the expanded category closes it.
  void toggleCategory(String categoryId) {
    _expandedCategoryId =
        _expandedCategoryId == categoryId ? null : categoryId;

    _openDropdownExerciseId = null;

    _notify();
  }

  /// Toggles the difficulty dropdown for the selected exercise.
  void toggleDropdown(TrainingExercise exercise) {
    _openDropdownExerciseId =
        _openDropdownExerciseId == exercise.id
            ? null
            : exercise.id;

    _notify();
  }

  /// Saves the selected difficulty and closes its dropdown.
  void selectDifficulty(
    TrainingExercise exercise,
    Difficulty difficulty,
  ) {
    _selected[exercise.id] = difficulty;

    _openDropdownExerciseId = null;

    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}