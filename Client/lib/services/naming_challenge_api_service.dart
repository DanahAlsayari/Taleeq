
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';
import 'auth_storage.dart';

class NamingChallengeApiService {
  String get _baseUrl =>
      ApiConfig.baseUrl.replaceFirst(RegExp(r'/auth/?$'), '');

  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    return {'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map) {
      throw Exception('استجابة غير متوقعة من الخادم.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final detail = _decodeResponse(response)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}

    return fallback;
  }

  Future<Map<String, dynamic>> getRandomPrompt({
    required String difficulty,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/games/naming-challenge/prompts/random',
    ).replace(queryParameters: {'difficulty': difficulty});

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 200) return _decodeResponse(response);
    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }
    if (response.statusCode == 404) {
      throw Exception('لا توجد أسئلة متاحة لهذا المستوى حاليًا.');
    }

    throw Exception(
      _errorMessage(response, 'تعذر تحميل سؤال التحدي.'),
    );
  }

  Future<Map<String, dynamic>> analyzeRecording({
    required int promptId,
    required String recordingPath,
  }) async {
    final file = File(recordingPath);

    if (!await file.exists() || await file.length() == 0) {
      throw Exception('التسجيل فارغ أو غير موجود. أعد التسجيل.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/games/naming-challenge/analyze'),
    );

    request.headers.addAll(await _headers());
    request.fields['prompt_id'] = promptId.toString();
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        recordingPath,
        filename: 'naming_challenge.wav',
      ),
    );

    final response = await http.Response.fromStream(
      await request.send(),
    );

    if (response.statusCode == 200) return _decodeResponse(response);
    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }
    if (response.statusCode == 404) {
      throw Exception('سؤال التحدي غير موجود.');
    }
    if (response.statusCode == 413) {
      throw Exception('حجم التسجيل أكبر من الحد المسموح.');
    }
    if (response.statusCode == 400 || response.statusCode == 422) {
      throw Exception(_errorMessage(response, 'تعذر تحليل التسجيل.'));
    }
    if (response.statusCode == 502) {
      throw Exception('تعذر تحليل التسجيل حاليًا. حاول مرة أخرى.');
    }

    throw Exception(
      _errorMessage(
        response,
        'حدث خطأ أثناء تحليل التسجيل (${response.statusCode}).',
      ),
    );
  }

  Future<Map<String, dynamic>> getAttempts({int limit = 50}) async {
    final uri = Uri.parse(
      '$_baseUrl/games/naming-challenge/attempts',
    ).replace(
      queryParameters: {'limit': limit.toString()},
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 200) return _decodeResponse(response);
    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    throw Exception(
      _errorMessage(response, 'تعذر تحميل سجل محاولات تحدي التعداد.'),
    );
  }
}
