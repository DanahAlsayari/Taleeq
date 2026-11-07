import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config_service.dart';
import 'auth_storage.dart';

class PracticeStreakService {
  Future<Map<String, dynamic>> getStreak() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('يرجى تسجيل الدخول مجددًا.');
    }

    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/practice-streak'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل سلسلة الممارسة.');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic> ||
        decoded['current_streak'] is! int ||
        decoded['longest_streak'] is! int ||
        decoded['practiced_today'] is! bool) {
      throw Exception('تعذر قراءة سلسلة الممارسة.');
    }

    return decoded;
  }
}
