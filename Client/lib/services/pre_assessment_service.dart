import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_storage.dart';

class PreAssessmentService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://10.0.2.2:8000';
  }
  Future<List<Map<String, dynamic>>> getQuestions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assessments/pre-assessment/questions'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final questions = data['questions'] as List<dynamic>;

      return questions
          .map((question) => Map<String, dynamic>.from(question as Map))
          .toList();
    }

    throw Exception(
      'Failed to load pre-assessment questions: '
      '${response.statusCode}',
    );
  }

  Future<Map<String, dynamic>> submitAnswers(
    List<Map<String, dynamic>> answers,
  ) async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/assessments/pre-assessment/submissions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'answers': answers}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    String message = 'Submission failed: ${response.statusCode}';

    try {
      final errorData = jsonDecode(response.body) as Map<String, dynamic>;

      if (errorData['detail'] != null) {
        message = errorData['detail'].toString();
      }
    } catch (_) {
      // Keep the original status-code message.
    }

    throw Exception(message);
  }
}
