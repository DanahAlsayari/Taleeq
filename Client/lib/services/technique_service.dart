
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/technique_model.dart';

class TechniqueService {
  // Android Emulator backend address.
  // For a physical iPhone, use a reachable backend address.
  static const String _baseUrl = 'http://192.168.68.56:8000';

  // Retrieve all techniques for the selection bottom sheet.
  Future<List<TechniqueModel>> getAllTechniques() async {
    final url = Uri.parse('$_baseUrl/techniques');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch techniques. HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! List) {
        throw const FormatException(
          'Expected a list of techniques',
        );
      }

      return decoded.map<TechniqueModel>((item) {
        return TechniqueModel.fromJson(
          item as Map<String, dynamic>,
        );
      }).toList();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[TechniqueService] List error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  // Retrieve full details of the selected technique.
  Future<TechniqueModel> getTechnique(int techniqueId) async {
    final url = Uri.parse('$_baseUrl/techniques/$techniqueId');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(
          utf8.decode(response.bodyBytes),
        ) as Map<String, dynamic>;

        return TechniqueModel.fromJson(json);
      }

      if (response.statusCode == 404) {
        throw Exception('Technique not found: $techniqueId');
      }

      throw Exception(
        'Failed to fetch technique. HTTP ${response.statusCode}',
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[TechniqueService] ERROR: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }
}
