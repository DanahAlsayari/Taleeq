import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_storage.dart';

class AssessmentApiService {
  static String get baseUrl {
      if (kIsWeb) {
        return 'http://127.0.0.1:8000';
      }

      return 'http://10.0.2.2:8000';
    }
  Future<void> analyzeLatestAssessment() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/assessments/analyze-latest',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 404) {
      throw Exception(
        'لم يتم العثور على تقييم.',
      );
    }

    if (response.statusCode == 400) {
      final body = jsonDecode(response.body);

      throw Exception(
        body['detail'] ??
            'فشل تحليل التقييم.',
      );
    }

    if (response.statusCode == 401) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول.',
      );
    }

    throw Exception(
      'حدث خطأ أثناء تحليل التقييم '
      '(${response.statusCode})',
    );
  }
}