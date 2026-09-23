import 'dart:convert';

import 'package:http/http.dart' as http;

class PreAssessmentService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<List<Map<String, dynamic>>> getQuestions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assessments/pre-assessment/questions'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final questions =
          data['questions'] as List<dynamic>;

      return questions
          .map(
            (question) =>
                Map<String, dynamic>.from(question as Map),
          )
          .toList();
    }

    throw Exception(
      'Failed to load pre-assessment questions: ${response.statusCode}',
    );
  }
}