
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';
import 'auth_storage.dart';

class DontSayItApiService {
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

      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {}

    return fallback;
  }


    Future<Map<String, dynamic>> getRandomChallenge({
      required String difficulty,
    }) async {
      final uri = Uri.parse(
        '$_baseUrl/games/dont-say-it/challenges/random',
      ).replace(
        queryParameters: {'difficulty': difficulty},
      );

      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return _decodeResponse(response);
      }

      if (response.statusCode == 401) {
        throw Exception('انتهت جلسة تسجيل الدخول.');
      }

      if (response.statusCode == 404) {
        throw Exception('لا توجد تحديات متاحة لهذا المستوى حاليًا.');
      }

      throw Exception(
        _errorMessage(response, 'تعذر تحميل التحدي.'),
      );
    }

  Future<Map<String, dynamic>> analyzeRecording({
    required int challengeId,
    required String recordingPath,
  }) async {
    final file = File(recordingPath);

    if (!await file.exists() || await file.length() == 0) {
      throw Exception('التسجيل فارغ أو غير موجود. أعد التسجيل.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/games/dont-say-it/analyze'),
    );

    request.headers.addAll(await _headers());
    request.fields['challenge_id'] = challengeId.toString();

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        recordingPath,
        filename: 'dont_say_it.wav',
      ),
    );

    final response = await http.Response.fromStream(
      await request.send(),
    );

    if (response.statusCode == 200) {
      return _decodeResponse(response);
    }

    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    if (response.statusCode == 404) {
      throw Exception('التحدي غير موجود.');
    }

    if (response.statusCode == 413) {
      throw Exception('حجم التسجيل أكبر من الحد المسموح.');
    }

    if (response.statusCode == 400 ||
        response.statusCode == 422) {
      throw Exception(
        _errorMessage(response, 'تعذر تحليل التسجيل.'),
      );
    }

    if (response.statusCode == 502) {
      throw Exception(
        'تعذر تحليل التسجيل حاليًا. حاول مرة أخرى.',
      );
    }

    throw Exception(
      _errorMessage(
        response,
        'حدث خطأ أثناء تحليل التسجيل (${response.statusCode}).',
      ),
    );
  }
}
