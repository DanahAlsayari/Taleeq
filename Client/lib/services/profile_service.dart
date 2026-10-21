import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';
import '../../services/api_config_service.dart';

class ProfileService {

  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.authBaseUrl}/profile'),
      headers: await _headers(),
    );

    return _decodeMap(response);
  }

  Future<List<dynamic>> getGoals() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    _throwRequestError(response);
  }

  Future<Map<String, dynamic>> addGoal(String goal) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals'),
      headers: await _headers(),
      body: jsonEncode({
        'goal': goal,
      }),
    );

    return _decodeMap(response);
  }

  // Update goal text or completion status
  Future<Map<String, dynamic>> updateGoal(
    int goalId, {
    String? goal,
    bool? isCompleted,
  }) async {
    final Map<String, dynamic> data = {};

    if (goal != null) {
      data['goal'] = goal;
    }

    if (isCompleted != null) {
      data['is_completed'] = isCompleted;
    }

    final response = await http.put(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals/$goalId'),
      headers: await _headers(),
      body: jsonEncode(data),
    );

    return _decodeMap(response);
  }

  Future<void> deleteGoal(int goalId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals/$goalId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      _throwRequestError(response);
    }
  }

  Future<Map<String, dynamic>> getReminder() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/reminder'),
      headers: await _headers(),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateReminder({
    required bool enabled,
    required String reminderTime,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/reminder'),
      headers: await _headers(),
      body: jsonEncode({
        'enabled': enabled,
        'reminder_time': reminderTime,
      }),
    );

    return _decodeMap(response);
  }

  Map<String, dynamic> _decodeMap(
    http.Response response,
  ) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    _throwRequestError(response);
  }

  Never _throwRequestError(
    http.Response response,
  ) {
    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }

    throw Exception(
      'Request failed: ${response.statusCode}',
    );
  }
}