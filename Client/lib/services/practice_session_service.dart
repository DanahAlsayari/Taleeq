import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';
import 'auth_storage.dart';

class PracticeSessionException implements Exception {
  const PracticeSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PracticeSessionService {
  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw const PracticeSessionException('يرجى تسجيل الدخول مجددًا.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> prepareToday({
    bool additionalSession = false,
  }) async {
    final headers = await _headers();

    return _send(
      () => http.post(
        Uri.parse('${ApiConfig.baseUrl}/practice-sessions/today'),
        headers: headers,
        body: jsonEncode({'additional_session': additionalSession}),
      ),
    );
  }

  Future<Map<String, dynamic>> getSession(int sessionId) async {
    final headers = await _headers();

    return _send(
      () => http.get(
        Uri.parse('${ApiConfig.baseUrl}/practice-sessions/$sessionId'),
        headers: headers,
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;

    try {
      response = await request().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const PracticeSessionException(
        'استغرق الطلب وقتًا طويلًا. يرجى المحاولة مجددًا.',
      );
    } catch (_) {
      throw const PracticeSessionException(
        'تعذر الاتصال بالخادم. تحقق من اتصالك وحاول مجددًا.',
      );
    }

    if (response.statusCode == 401) {
      throw const PracticeSessionException(
        'انتهت جلسة الدخول. يرجى تسجيل الدخول مجددًا.',
      );
    }

    Map<String, dynamic>? data;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      // An unexpected response is handled below.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data == null ||
          data['session_id'] is! int ||
          data['exercises'] is! List) {
        throw const PracticeSessionException('تعذر قراءة بيانات الجلسة.');
      }

      return data;
    }

    final detail = data?['detail'];

    final message = switch (detail) {
      'Complete a speech assessment before generating a session.' =>
        'أكمل تقييم الكلام أولًا للحصول على جلسة مخصصة.',
      'The latest completed assessment has no usable task results.' =>
        'تعذر العثور على نتائج مهام التقييم.',
      'Practice session not found.' => 'تعذر العثور على الجلسة.',
      'No suitable exercise fits the selected recording-time budget.' =>
        'لا يتوفر تمرين مناسب للمدة المحددة.',
      _ => 'تعذر تحميل الجلسة. يرجى المحاولة مجددًا.',
    };

    throw PracticeSessionException(message);
  }
}
