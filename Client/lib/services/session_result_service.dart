import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/session_result_model.dart';
import 'api_config_service.dart';
import 'auth_storage.dart';
import 'practice_session_service.dart' show PracticeSessionException;

/// Reads session results from the backend.
///
/// GET /practice-sessions/history
/// GET /practice-sessions/{id}/result
/// GET /practice-sessions/{id}/exercises/{session_exercise_id}/result
class SessionResultService {
  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw const PracticeSessionException('يرجى تسجيل الدخول مجددًا.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<SessionHistoryItem>> fetchHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _get('/practice-sessions/history?limit=$limit&offset=$offset');

    final sessions = data['sessions'];

    if (sessions is! List) {
      return const [];
    }

    return sessions
        .whereType<Map>()
        .map(
          (item) =>
              SessionHistoryItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<SessionResultData> fetchSessionResult(int sessionId) async {
    final data = await _get('/practice-sessions/$sessionId/result');

    return SessionResultData.fromJson(data);
  }

  Future<ExerciseResultData> fetchExerciseResult(
    int sessionId,
    int sessionExerciseId,
  ) async {
    final data = await _get(
      '/practice-sessions/$sessionId/exercises/$sessionExerciseId/result',
    );

    return ExerciseResultData.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final headers = await _headers();
    final http.Response response;

    try {
      response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: headers)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const PracticeSessionException(
        'استغرق الطلب وقتًا طويلًا. يرجى المحاولة مجددًا.',
      );
    } catch (_) {
      throw const PracticeSessionException(
        'تعذر الاتصال بالخادم. تحقق من اتصالك وحاول مجددًا.',
      );
    }

    if (response.statusCode == 401) {
      throw const PracticeSessionException(
        'انتهت جلسة الدخول. يرجى تسجيل الدخول مجددًا.',
      );
    }

    if (response.statusCode == 404) {
      throw const PracticeSessionException('تعذر العثور على النتيجة.');
    }

    Map<String, dynamic>? data;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      // Handled below.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data == null) {
        throw const PracticeSessionException('تعذر قراءة بيانات النتيجة.');
      }

      return data;
    }

    throw const PracticeSessionException(
      'تعذر تحميل النتيجة. يرجى المحاولة مجددًا.',
    );
  }
}
