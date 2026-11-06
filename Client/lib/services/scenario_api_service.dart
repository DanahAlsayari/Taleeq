import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/scenario_model.dart';
import '../models/scenario_difficulty_model.dart';
import '../models/scenario_attempt_model.dart';
import 'api_config_service.dart';
import 'auth_storage.dart';

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
}