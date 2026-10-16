import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class SignupOtpException implements Exception {
  const SignupOtpException(this.message, {this.retryAfterSeconds});

  final String message;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}

class SignupOtpService {
  Future<Map<String, dynamic>> verify({
    required String registrationId,
    required String code,
  }) {
    return _post('/signup/verify', {
      'registration_id': registrationId,
      'code': code,
    });
  }

  Future<Map<String, dynamic>> resend({required String registrationId}) {
    return _post('/signup/resend', {'registration_id': registrationId});
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response response;

    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.authBaseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const SignupOtpException(
        'تعذر الاتصال بالخادم. تحقق من اتصالك وحاول مرة أخرى.',
      );
    }

    Map<String, dynamic>? data;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      // Handle an unexpected response below.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data == null) {
        throw const SignupOtpException(
          'تعذر قراءة استجابة الخادم. يرجى المحاولة مرة أخرى.',
        );
      }

      return data;
    }

    final detail = data?['detail'];
    String message = 'تعذر إكمال الطلب. يرجى المحاولة مرة أخرى.';

    if (detail is String) {
      message = switch (detail) {
        'Email already registered' =>
          'البريد الإلكتروني مستخدم بالفعل. يرجى تسجيل الدخول.',
        'Phone number already registered' =>
          'رقم الهاتف مستخدم بالفعل. يرجى العودة والتحقق من البيانات.',
        'Email and phone number already registered' =>
          'البريد الإلكتروني ورقم الهاتف مستخدمان بالفعل.',
        _ => RegExp(r'[\u0600-\u06FF]').hasMatch(detail) ? detail : message,
      };
    } else if (response.statusCode == 422) {
      message = 'يرجى إدخال رمز تحقق مكوّن من 6 أرقام.';
    }

    throw SignupOtpException(
      message,
      retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''),
    );
  }
}
