import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/api_config_service.dart';
import '../../../services/auth_storage.dart';

import 'models/training_models.dart';

class TrainingApiService {
  const TrainingApiService();

  /// Converts Flutter exercise types to backend values.
  String _backendExerciseType(ExerciseType type) {
    switch (type) {
      case ExerciseType.reading:
        return 'Reading';

      case ExerciseType.pictureDescription:
        return 'Picture Description';

      case ExerciseType.questionAnswer:
        return 'Question & Answer';

      case ExerciseType.storytelling:
        return 'Storytelling';

      case ExerciseType.freeSpeech:
        return 'Free Speech';

      case ExerciseType.realLifeScenarios:
      case ExerciseType.wordLetterChallenge:
      case ExerciseType.sentenceBuilding:
      case ExerciseType.dualTask:
        throw UnsupportedError('This exercise type uses a different API.');
    }
  }

  /// Converts Flutter difficulty to backend difficulty.
  String _backendDifficulty(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 'Easy';

      case Difficulty.medium:
        return 'Medium';

      case Difficulty.advanced:
        return 'Hard';
    }
  }

  /// Fetches a random exercise for the logged-in user.

Future<Map<String, dynamic>> fetchRandomExercise(
  ExerciseSelection selection,
) async {
  final token = await AuthStorage.getToken();

  if (token == null || token.isEmpty) {
    throw Exception('Please log in before starting an exercise.');
  }

  final uri = Uri.parse(
    '${ApiConfig.baseUrl}/training/random-exercise',
  ).replace(
    queryParameters: {
      'exercise_type': _backendExerciseType(selection.type),
      'difficulty': _backendDifficulty(selection.difficulty),
    },
  );

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    },
  ).timeout(const Duration(seconds: 15));

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const FormatException(
      'Unexpected exercise response format.',
    );
  }

  if (response.statusCode == 401) {
    throw Exception(
      'Your session has expired. Please log in again.',
    );
  }

  if (response.statusCode == 404) {
    throw Exception(
      'No exercises are available for this type and difficulty.',
    );
  }

  throw Exception(
    'Failed to load exercise (${response.statusCode}).',
  );
}

}
