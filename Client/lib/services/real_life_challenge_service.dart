import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';
import 'auth_storage.dart';

class RealLifeChallengeService {
  static const _path = '/real-life-challenges';

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('يرجى تسجيل الدخول مجددًا.');
    }

    final client = http.Client();

    try {
      final request = http.Request(
        method,
        Uri.parse('${ApiConfig.baseUrl}$_path$path'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }

      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));

      dynamic decoded;

      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw Exception('تعذر قراءة استجابة الخادم.');
      }

      if (response.statusCode == 401) {
        throw Exception('انتهت جلسة الدخول. يرجى تسجيل الدخول مجددًا.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];

          if (detail is String && detail.isNotEmpty) {
            throw Exception(detail);
          }
        }

        throw Exception('تعذر تنفيذ الطلب. حاول مجددًا.');
      }

      return decoded;
    } on TimeoutException {
      throw Exception('استغرق الاتصال وقتًا طويلًا. حاول مجددًا.');
    } on http.ClientException {
      throw Exception('تعذر الاتصال بالخادم. تحقق من الاتصال.');
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _readAttempt(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! int ||
        value['challenge_id'] is! int ||
        value['title'] is! String ||
        value['instructions'] is! String ||
        value['is_current'] is! bool ||
        value['is_completed'] is! bool ||
        value['assigned_at'] is! String) {
      throw Exception('تعذر قراءة بيانات التحدّي.');
    }

    return value;
  }

  /// Read the current challenge without creating an assignment.
  Future<Map<String, dynamic>?> getCurrent() async {
    final decoded = await _request('GET', '/current');

    if (decoded == null) {
      return null;
    }

    return _readAttempt(decoded);
  }

  /// Return the existing challenge or assign the first one.
  /// Calling this again keeps the same assignment.
  Future<Map<String, dynamic>> ensureCurrent() async {
    final decoded = await _request('POST', '/current');
    return _readAttempt(decoded);
  }

  Future<Map<String, dynamic>> updateCompletion({
    required int attemptId,
    required bool isCompleted,
  }) async {
    final decoded = await _request(
      'PATCH',
      '/$attemptId/completion',
      body: {'is_completed': isCompleted},
    );

    return _readAttempt(decoded);
  }

  Future<Map<String, dynamic>> saveReflection({
    required int attemptId,
    required String reflection,
  }) async {
    final decoded = await _request(
      'PUT',
      '/$attemptId/reflection',
      body: {'reflection': reflection.trim()},
    );

    return _readAttempt(decoded);
  }

  /// Available after completing the current challenge.
  Future<Map<String, dynamic>> nextChallenge({required int attemptId}) async {
    final decoded = await _request('POST', '/$attemptId/next');

    return _readAttempt(decoded);
  }

  Future<Map<String, dynamic>> getHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Invalid history pagination.');
    }

    final decoded = await _request(
      'GET',
      '/history?limit=$limit&offset=$offset',
    );

    if (decoded is! Map<String, dynamic> ||
        decoded['items'] is! List ||
        decoded['has_more'] is! bool) {
      throw Exception('تعذر قراءة سجل التحدّيات.');
    }

    final items = (decoded['items'] as List).map(_readAttempt).toList();

    return {'items': items, 'has_more': decoded['has_more']};
  }
}
