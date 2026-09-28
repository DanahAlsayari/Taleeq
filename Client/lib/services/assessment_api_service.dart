import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'auth_storage.dart';

class AssessmentApiService {
  String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    return {
      'Authorization': 'Bearer $token',
    };
  }

  Future<int> createAssessment() async {
    final response = await http.post(
      Uri.parse('$baseUrl/assessments/create'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      return body['assessment_id'] as int;
    }

    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    throw Exception(
      'فشل إنشاء التقييم (${response.statusCode})',
    );
  }

  // =========================================================
  // NEW: Analyze local audio files directly
  // =========================================================

  Future<void> analyzeAssessmentAudio({
    required int assessmentId,
    required Map<int, String> recordingPaths,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    if (recordingPaths.isEmpty) {
      throw Exception('لا توجد تسجيلات للتحليل.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/assessments/$assessmentId/analyze-audio',
      ),
    );

    request.headers['Authorization'] = 'Bearer $token';

    final sortedEntries = recordingPaths.entries.toList()
      ..sort(
        (a, b) => a.key.compareTo(b.key),
      );

    // Add audio files
    for (final entry in sortedEntries) {
      final questionIndex = entry.key;
      final filePath = entry.value;

      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception(
          'ملف التسجيل غير موجود: $filePath',
        );
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'files',
          filePath,
          filename: 'assessment_q${questionIndex + 1}.wav',
        ),
      );
    }

    // Add all task types as one JSON field
    final taskTypes = sortedEntries
        .map(
          (entry) => 'task_${entry.key + 1}',
        )
        .toList();

    request.fields['task_types'] = jsonEncode(taskTypes);

    print('🎙️ SENDING AUDIO FILES');
    print('📁 FILE COUNT: ${request.files.length}');
    print(
      '📝 TASK TYPES SENT: ${request.fields['task_types']}',
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    print(
      '📡 ANALYSIS STATUS: ${response.statusCode}',
    );

    print(
      '📦 ANALYSIS RESPONSE: ${response.body}',
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'غير مصرح بهذا التقييم.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'التقييم غير موجود.',
      );
    }

    if (response.statusCode == 400) {
      try {
        final body = jsonDecode(response.body);

        throw Exception(
          body['detail'] ??
              'فشل تحليل التسجيلات.',
        );
      } catch (_) {
        throw Exception(
          'فشل تحليل التسجيلات.',
        );
      }
    }

    throw Exception(
      'حدث خطأ أثناء تحليل التسجيلات '
      '(${response.statusCode})',
    );
  }

  // =========================================================
  // OLD FLOW - Keep temporarily
  // =========================================================

  Future<void> createAssessmentTask({
    required int assessmentId,
    required String taskType,
    required String storageUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assessments/tasks'),
      headers: {
        ...(await _headers()),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'assessment_id': assessmentId,
        'task_type': taskType,
        'storage_url': storageUrl,
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 404) {
      throw Exception('التقييم غير موجود.');
    }

    if (response.statusCode == 403) {
      throw Exception('غير مصرح بهذا التقييم.');
    }

    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    throw Exception(
      'فشل حفظ مهمة التقييم (${response.statusCode})',
    );
  }

  Future<void> analyzeLatestAssessment() async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/assessments/analyze-latest',
      ),
      headers: await _headers(),
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