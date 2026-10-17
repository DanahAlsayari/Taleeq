import 'package:flutter/foundation.dart';

class ApiConfig {


  static String get baseUrl {
    return 'http://192.168.3.37:8000';
  }

  static String get authBaseUrl => '$baseUrl/auth';
}
