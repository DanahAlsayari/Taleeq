import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/progress_assessment_model.dart';
import '../models/fluency_profile_data.dart';
import 'api_config_service.dart';
import 'auth_storage.dart';
import 'progress_calculator.dart';

class ProgressService {
  String get _baseUrl =>
      ApiConfig.baseUrl.replaceFirst(RegExp(r'/auth/?$'), '');
  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('يرجى تسجيل الدخول أولاً.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all completed assessments for the current user.
  Future<List<ProgressAssessment>> getAssessmentHistory() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/assessments/history'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

      return data
          .map(
            (item) => ProgressAssessment.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    _handleError(response);
  }

  // Get the results of a specific assessment.
  Future<FluencyProfileData> getAssessmentDetails(int assessmentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/assessments/$assessmentId/details'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      return FluencyProfileData.fromJson(data);
    }

    _handleError(response);
  }

  Future<List<AssessmentProgressData>> getAllAssessmentDetails(
    List<ProgressAssessment> assessments,
  ) async {
    return Future.wait(
      assessments.map((assessment) async {
        final details = await getAssessmentDetails(assessment.assessmentId);

        return AssessmentProgressData(assessment: assessment, details: details);
      }),
    );
  }

  Never _handleError(http.Response response) {
    switch (response.statusCode) {
      case 401:
        throw Exception('انتهت جلسة تسجيل الدخول.');
      case 403:
        throw Exception('ليس لديك صلاحية لعرض هذا التقييم.');
      case 404:
        throw Exception('لم يتم العثور على التقييم.');
      default:
        throw Exception('فشل تحميل البيانات (${response.statusCode})');
    }
  }
}
