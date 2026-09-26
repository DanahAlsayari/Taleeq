import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_storage.dart';

class ProfileService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://10.0.2.2:8000';
  }
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
      Uri.parse('$baseUrl/profile'),
      headers: await _headers(),
    );

    return _decodeMap(response);
  }

  Future<List<dynamic>> getGoals() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/goals'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    _throwRequestError(response);
  }

  Future<Map<String, dynamic>> addGoal(String goal) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/goals'),
      headers: await _headers(),
      body: jsonEncode({'goal': goal}),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateGoal(int goalId, String goal) async {
    final response = await http.put(
      Uri.parse('$baseUrl/profile/goals/$goalId'),
      headers: await _headers(),
      body: jsonEncode({'goal': goal}),
    );

    return _decodeMap(response);
  }

  Future<void> deleteGoal(int goalId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/profile/goals/$goalId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      _throwRequestError(response);
    }
  }

  Future<Map<String, dynamic>> getReminder() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/reminder'),
      headers: await _headers(),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateReminder({
    required bool enabled,
    required String reminderTime,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/profile/reminder'),
      headers: await _headers(),
      body: jsonEncode({'enabled': enabled, 'reminder_time': reminderTime}),
    );

    return _decodeMap(response);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _throwRequestError(response);
  }

  Never _throwRequestError(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }

    throw Exception('Request failed: ${response.statusCode}');
  }
}
