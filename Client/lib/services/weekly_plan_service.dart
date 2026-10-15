import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';
import 'auth_storage.dart';

class WeeklyPlanService {
  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('يرجى تسجيل الدخول مجددًا');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw Exception('تعذر قراءة استجابة الخادم');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception('انتهت جلسة الدخول. يرجى تسجيل الدخول مجددًا');
    }

    if (decoded is Map && decoded['detail'] is String) {
      throw Exception(decoded['detail']);
    }

    throw Exception('تعذر تنفيذ الطلب. يرجى المحاولة مرة أخرى');
  }

  Future<Map<String, dynamic>?> getWeeklyPlan({String? weekStart}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/weekly-plan');

    final response = await http
        .get(
          weekStart == null
              ? uri
              : uri.replace(queryParameters: {'week_start': weekStart}),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = _decodeResponse(response);

    if (decoded == null) return null;

    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> saveWeeklyPlan({
    required String weekStart,
    required List<Map<String, dynamic>> sessions,
  }) async {
    final response = await http
        .put(
          Uri.parse('${ApiConfig.baseUrl}/weekly-plan'),
          headers: await _headers(),
          body: jsonEncode({'week_start': weekStart, 'sessions': sessions}),
        )
        .timeout(const Duration(seconds: 20));

    return Map<String, dynamic>.from(_decodeResponse(response) as Map);
  }

  Future<Map<String, dynamic>> updateCompletion({
    required int sessionId,
    required bool isCompleted,
  }) async {
    final response = await http
        .patch(
          Uri.parse(
            '${ApiConfig.baseUrl}/weekly-plan/'
            'sessions/$sessionId/completion',
          ),
          headers: await _headers(),
          body: jsonEncode({'is_completed': isCompleted}),
        )
        .timeout(const Duration(seconds: 20));

    return Map<String, dynamic>.from(_decodeResponse(response) as Map);
  }
}
