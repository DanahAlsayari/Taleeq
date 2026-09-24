import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_storage.dart';
import '../../models/fluency_profile_data.dart';

class FluencyProfileService {
  static const String baseUrl = 'http://10.0.2.2:8000';

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

  Future<FluencyProfileData> getFluencyProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assessments/fluency-profile'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      return FluencyProfileData.fromJson(json);
    }

    if (response.statusCode == 404) {
      throw Exception('Fluency profile not found');
    }

    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }

    throw Exception('Request failed: ${response.statusCode}');
  }
}
