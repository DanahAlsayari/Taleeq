import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/technique_model.dart';

class TechniqueService {
  
  // NOTE: 10.0.2.2 is used to access the local backend from the Android Emulator.
  // For a physical device, replace it with the computer's local IP address
  // or a reachable backend URL.

  static const String _baseUrl = 'http://10.0.2.2:8000';

  Future<TechniqueModel> getTechnique(int techniqueId) async {
    final url = Uri.parse('$_baseUrl/techniques/$techniqueId');

    if (kDebugMode) {
      debugPrint('[TechniqueService] Requesting technique_id=$techniqueId');
      debugPrint('[TechniqueService] URL: $url');
    }

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint(
          '[TechniqueService] Response status: ${response.statusCode}',
        );
      }

      if (response.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        final technique = TechniqueModel.fromJson(json);

        if (kDebugMode) {
          debugPrint('[TechniqueService] Loaded technique_id=${technique.id}');
        }

        return technique;
      }

      if (response.statusCode == 404) {
        throw Exception('Technique not found: $techniqueId');
      }

      throw Exception('Failed to fetch technique. HTTP ${response.statusCode}');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[TechniqueService] ERROR: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      rethrow;
    }
  }
}
