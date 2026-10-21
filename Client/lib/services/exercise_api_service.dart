import 'dart:io';

import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_config_service.dart';
import 'auth_storage.dart';

import 'dart:async';

class ExerciseApiService {
  Future<Map<String, dynamic>> analyzeExerciseAudio({
    required String exerciseId,
    required String recordingPath,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    final file = File(recordingPath);

    if (!await file.exists() || await file.length() == 0) {
      throw Exception('التسجيل فارغ أو غير موجود. أعد التسجيل.');
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}/speech-exercises/$exerciseId/analyze-audio',
    );

    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(await http.MultipartFile.fromPath('file', recordingPath));
    late final http.Response response;

    try {
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );

      response = await http.Response.fromStream(streamedResponse);
    } on SocketException {
      throw Exception('تعذر الاتصال بالخادم. يرجى المحاولة مرة أخرى.');
    } on http.ClientException {
      throw Exception('تعذر الاتصال بالخادم. يرجى المحاولة مرة أخرى.');
    } on TimeoutException {
      throw Exception(
        'استغرق الاتصال بالخادم وقتًا طويلًا. يرجى المحاولة مرة أخرى.',
      );
    }

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    }

    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    if (response.statusCode == 403) {
      throw Exception('غير مصرح لك بهذا التمرين.');
    }

    if (response.statusCode == 404) {
      throw Exception('التمرين غير موجود.');
    }

    if (response.statusCode == 400 || response.statusCode == 422) {
      var message = 'تعذر تحليل التسجيل. حاول مرة أخرى.';

      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));

        if (body is Map && body['detail'] is String) {
          final detail = body['detail'] as String;

          if (detail.isNotEmpty) {
            message = detail;
          }
        }
      } catch (_) {
        // Keep the default error message.
      }

      throw Exception(message);
    }

    throw Exception('حدث خطأ أثناء تحليل التسجيل (${response.statusCode}).');
  }

  Future<Map<String, int>> getAttemptsStat() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('سجّلي دخولك أولًا');
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}/speech-exercises/attempts/stats',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('فشل جلب إحصائيات التدريب (${response.statusCode})');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return {
      'total_attempts': (data['total_attempts'] as num).toInt(),
      'total_duration_seconds': (data['total_duration_seconds'] as num).toInt(),
    };
  }

  Future<List<Map<String, dynamic>>> getRecentAttempts() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('سجّلي دخولك أولًا');
    }
    final uri = Uri.parse(
      '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}/speech-exercises/attempts/recent',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('فشل جلب المحاولات السابقة: ${response.body}');
    }

    final data = jsonDecode(response.body) as List;

    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllAttempts() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('سجّلي دخولك أولًا');
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}/speech-exercises/attempts/all',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('فشل جلب سجل المحاولات (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
