import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config_service.dart';
import 'auth_storage.dart';

class ExerciseApiService {
  Future<Map<String, dynamic>> analyzeExerciseAudio({
    required String exerciseId,
    required String recordingPath,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('سجّلي دخولك أولًا');
    }

    final uri = Uri.parse(
  '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}/speech-exercises/$exerciseId/analyze-audio',
    );

    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        recordingPath,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        'فشل تحليل التسجيل (${response.statusCode}): $responseBody',
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(responseBody) as Map,
    );
  }


  Future<List<Map<String, dynamic>>> getExercises() async {
  final token = await AuthStorage.getToken();

  if (token == null || token.isEmpty) {
    throw Exception('سجّلي دخولك أولًا');
  }

  final uri = Uri.parse(
  '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}/speech-exercises/?difficulty=Medium',
);

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
      'فشل جلب التمارين (${response.statusCode}): ${response.body}',
    );
  }

  final data = jsonDecode(response.body) as List;

  return data
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}
Future<List<Map<String, dynamic>>> getRecentAttempts() async {
  final token = await AuthStorage.getToken();

  if (token == null || token.isEmpty) {
    throw Exception('سجّلي دخولك أولًا');
  }
  final uri = Uri.parse(
    '${ApiConfig.baseUrl.replaceFirst(RegExp(r"/auth/?$"), "")}/speech-exercises/attempts/recent',
  );

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
      'فشل جلب المحاولات السابقة: ${response.body}',
    );
  }

  final data = jsonDecode(response.body) as List;

  return data
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}


}