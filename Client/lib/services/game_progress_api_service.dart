import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';
import 'auth_storage.dart';

/// Fetches saved progress and attempt history for Taleeq speaking games.
class GameProgressApiService {
  String get _baseUrl =>
      ApiConfig.baseUrl.replaceFirst(RegExp(r'/auth/?$'), '');

  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw Exception('تعذر قراءة بيانات نتائج الألعاب.');
    }

    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    if (decoded is Map && decoded['detail'] is String) {
      throw Exception(decoded['detail'] as String);
    }

    throw Exception('تعذر تحميل نتائج الألعاب.');
  }

  /// Latest saved attempts for Don't Say It, including speech analysis.
  Future<Map<String, dynamic>> getDontSayItProgress() {
    return _get('/games/dont-say-it/progress');
  }

  /// Aggregated scores by prompt for Naming Challenge.
  Future<Map<String, dynamic>> getNamingChallengeProgress() {
    return _get('/games/naming-challenge/scores');
  }

  /// Individual Naming Challenge attempts.
  ///
  /// Requires the backend endpoint GET /games/naming-challenge/attempts.
  Future<Map<String, dynamic>> getNamingChallengeAttempts() {
    return _get('/games/naming-challenge/attempts');
  }

  /// Loads both existing progress summaries.
  Future<Map<String, dynamic>> getAllGameProgress() async {
    final results = await Future.wait([
      getDontSayItProgress(),
      getNamingChallengeProgress(),
    ]);

    return {
      'dont_say_it': results[0],
      'naming_challenge': results[1],
    };
  }

  /// Loads both game histories for the Progress screen.
  Future<Map<String, dynamic>> getAllGameAttempts() async {
    final results = await Future.wait([
      getDontSayItProgress(),
      getNamingChallengeAttempts(),
    ]);

    return {
      'dont_say_it': results[0],
      'naming_challenge': results[1],
    };
  }
}
