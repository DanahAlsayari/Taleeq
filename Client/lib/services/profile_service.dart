import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_storage.dart';
import '../../services/api_config_service.dart';

import 'package:http_parser/http_parser.dart';

class ProfileService {
  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.authBaseUrl}/profile'),
      headers: await _headers(),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateProfileName(String name) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/name'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> requestEmailChange(String newEmail) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/email/request'),
      headers: await _headers(),
      body: jsonEncode({'new_email': newEmail.trim()}),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> verifyEmailChange({
    required String requestId,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/email/verify'),
      headers: await _headers(),
      body: jsonEncode({'request_id': requestId, 'code': code}),
    );

    final result = _decodeMap(response);

    final newToken = result['access_token']?.toString();

    if (newToken == null || newToken.isEmpty) {
      throw Exception('لم يتم استلام رمز تسجيل الدخول الجديد');
    }

    await AuthStorage.saveToken(newToken);

    return result;
  }

  Future<Map<String, dynamic>> resendEmailChange({
    required String requestId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/email/resend'),
      headers: await _headers(),
      body: jsonEncode({'request_id': requestId}),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> uploadProfilePicture({
    required XFile file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.authBaseUrl}/profile/picture'),
    );

    final headers = await _headers();
    request.headers['Authorization'] = headers['Authorization']!;

    final bytes = await file.readAsBytes();

    final extension = file.name.split('.').last.toLowerCase();

    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw Exception('صيغة الصورة غير مدعومة'),
    };

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 413) {
      throw Exception(
        'حجم الصورة كبير جدًا. يرجى اختيار صورة لا يتجاوز حجمها 2 ميجابايت.',
      );
    }

    if (response.statusCode == 400) {
      throw Exception(
        'الصورة غير مدعومة أو غير صالحة. يرجى اختيار صورة بصيغة JPG أو PNG أو WebP.',
      );
    }

    if (response.statusCode >= 500) {
      throw Exception('تعذر رفع الصورة حاليًا. يرجى المحاولة مرة أخرى.');
    }

    return _decodeMap(response);
  }

  Future<void> deleteProfilePicture() async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/picture'),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwRequestError(response);
    }
  }

  Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.authBaseUrl}/profile'),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwRequestError(response);
    }
  }

  Future<List<dynamic>> getGoals() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    _throwRequestError(response);
  }

  Future<Map<String, dynamic>> addGoal(String goal) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals'),
      headers: await _headers(),
      body: jsonEncode({'goal': goal}),
    );

    return _decodeMap(response);
  }

  // Update goal text or completion status
  Future<Map<String, dynamic>> updateGoal(
    int goalId, {
    String? goal,
    bool? isCompleted,
  }) async {
    final Map<String, dynamic> data = {};

    if (goal != null) {
      data['goal'] = goal;
    }

    if (isCompleted != null) {
      data['is_completed'] = isCompleted;
    }

    final response = await http.put(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals/$goalId'),
      headers: await _headers(),
      body: jsonEncode(data),
    );

    return _decodeMap(response);
  }

  Future<void> deleteGoal(int goalId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/goals/$goalId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      _throwRequestError(response);
    }
  }

  Future<Map<String, dynamic>> getReminder() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/reminder'),
      headers: await _headers(),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateReminder({
    required bool enabled,
    required String reminderTime,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.authBaseUrl}/profile/reminder'),
      headers: await _headers(),
      body: jsonEncode({'enabled': enabled, 'reminder_time': reminderTime}),
    );

    return _decodeMap(response);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _throwRequestError(response);
  }

  Never _throwRequestError(http.Response response) {
    String? detail;

    try {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        final errorDetail = data['detail'];

        if (errorDetail is String) {
          detail = errorDetail;
        }
      }
    } catch (_) {
      // The response may not contain valid JSON.
    }

    debugPrint(
      'PROFILE API ERROR: '
      '${response.statusCode} - ${detail ?? response.body}',
    );

    if (response.statusCode == 401) {
      throw Exception(detail ?? 'Unauthorized');
    }

    throw Exception(detail ?? 'Request failed: ${response.statusCode}');
  }
}
