import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/api_config_service.dart';
import '../../../services/auth_storage.dart';

class AiAssistantService {
  const AiAssistantService();

  Future<Map<String, dynamic>> sendMessage(
    List<Map<String, String>> messages,
  ) async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in to use Taleeq Assistant.');
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai-assistant/chat');

    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'messages': messages}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is Map<String, dynamic>) {
        return data;
      }

      throw const FormatException('Unexpected AI assistant response format.');
    }

    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    throw Exception(
      'Failed to get AI assistant response (${response.statusCode}).',
    );
  }
}
