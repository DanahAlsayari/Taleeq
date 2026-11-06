import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/scenario_model.dart';
import '../models/scenario_difficulty_model.dart';
import '../models/scenario_attempt_model.dart';
import 'api_config_service.dart';
import 'auth_storage.dart';

import 'dart:async';
import 'dart:io';
class ScenarioApiService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body is Map
        ? body['detail'] ?? body['message'] ?? 'Something went wrong.'
        : 'Something went wrong.';

    throw Exception(message.toString());
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Invalid server response.');
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      for (final key in ['scenarios', 'difficulties', 'items']) {
        if (data[key] is List) return data[key];
      }
    }

    throw Exception('Invalid list response from server.');
  }

  // 1. Get all active scenarios
  Future<List<ScenarioModel>> getScenarios() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/scenarios'),
      headers: await _getHeaders(),
    );

    final data = _decodeResponse(response);

    return _asList(data)
        .map((item) => ScenarioModel.fromJson(_asMap(item)))
        .toList();
  }

  // 2. Get scenario details and its active difficulties
  Future<List<ScenarioDifficultyModel>> getScenarioDifficulties(
    String scenarioId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/scenarios/$scenarioId'),
      headers: await _getHeaders(),
    );

    final data = _asMap(_decodeResponse(response));

    final difficulties = data['difficulties'] ?? data['scenario_difficulties'];

    if (difficulties is! List) {
      throw Exception('Difficulties not found in server response.');
    }

    return difficulties
        .map((item) => ScenarioDifficultyModel.fromJson(_asMap(item)))
        .toList();
  }

  // 3. Start a new scenario attempt
  Future<ScenarioAttemptModel> startScenario({
    required String scenarioId,
    required String difficultyId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/scenarios/$scenarioId/start',
    ).replace(
      queryParameters: {'difficulty_id': difficultyId},
    );

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
    );

    final data = _asMap(_decodeResponse(response));
    final attempt = data['attempt'] ?? data;

    return ScenarioAttemptModel.fromJson(_asMap(attempt));
  }

  // 4. Create a temporary Realtime session token
  Future<Map<String, dynamic>> createRealtimeSession(
    String attemptId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/scenarios/attempts/$attemptId/realtime-session',
      ),
      headers: await _getHeaders(),
    );

    return _asMap(_decodeResponse(response));
  }
 

// Add this method INSIDE ScenarioApiService.
// Keep all existing methods in that file unchanged.

Future<Map<String, dynamic>> analyzeScenarioAudio({
  required String attemptId,
  required String recordingPath,
  String endReason = 'user_ended',
}) async {
  final token = await AuthStorage.getToken();

  if (token == null || token.isEmpty) {
    throw Exception('انتهت جلسة تسجيل الدخول.');
  }

  final file = File(recordingPath);

  if (!await file.exists() || await file.length() == 0) {
    throw Exception('التسجيل فارغ أو غير موجود. أعيدي التسجيل.');
  }

  final uri = Uri.parse(
    '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}'
    '/scenarios/attempts/$attemptId/analyze-audio',
  );

  final request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer $token';
  request.fields['end_reason'] = endReason;
  request.files.add(
    await http.MultipartFile.fromPath('file', recordingPath),
  );

  late final http.Response response;

  try {
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 180),
    );
    response = await http.Response.fromStream(streamedResponse);
  } on SocketException {
    throw Exception('تعذر الاتصال بالخادم. يرجى المحاولة مرة أخرى.');
  } on http.ClientException {
    throw Exception('تعذر الاتصال بالخادم. يرجى المحاولة مرة أخرى.');
  } on TimeoutException {
    throw Exception('استغرق تحليل التسجيل وقتًا طويلًا. حاولي مرة أخرى.');
  }

  final decoded = jsonDecode(utf8.decode(response.bodyBytes));

  if (response.statusCode >= 200 && response.statusCode < 300) {
    if (decoded is! Map) {
      throw Exception('استجابة التحليل غير صالحة.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  if (response.statusCode == 401) {
    throw Exception('انتهت جلسة تسجيل الدخول.');
  }

  final message = decoded is Map && decoded['detail'] is String
      ? decoded['detail'] as String
      : 'حدث خطأ أثناء تحليل التسجيل (${response.statusCode}).';

  throw Exception(message);
}

}