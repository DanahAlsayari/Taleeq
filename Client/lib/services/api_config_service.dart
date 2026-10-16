import 'package:flutter/foundation.dart';

class ApiConfig {
  // Optional backend address supplied when launching Flutter.
  static const String _configuredUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Main backend address without /auth.
  static String get apiBaseUrl {
    if (_configuredUrl.isNotEmpty) {
      return _configuredUrl
          .replaceAll(RegExp(r'/$'), '')
          .replaceFirst(RegExp(r'/auth$'), '');
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    // For a physical iPhone, provide the server address
    // using --dart-define=API_BASE_URL=...
    return '';
  }

  // Authentication endpoints used by existing login,
  // signup, and password recovery screens.
  static String get baseUrl {
    return '$apiBaseUrl/auth';
  }
}