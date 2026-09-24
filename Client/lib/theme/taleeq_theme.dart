import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaleeqTheme {
  TaleeqTheme._();

  static const Color primaryTeal = Color(0xFF1F5F5A);
  static const Color mediumTeal = Color(0xFF6FA7A3);
  static const Color softTeal = Color(0xFFCFE4E1);

  static const Color warmCream = Color(0xFFF7EAD7);
  static const Color softPeach = Color(0xFFF2D3C6);

  static const Color darkSlate = Color(0xFF2E3A38);
  static const Color warmBackground = Color(0xFFFFFCF8);

  static const Color borderSubtle = Color(0xFFE8EFEF);
  static const Color textMuted = Color(0xFF6B7E7B);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: darkSlate.withValues(alpha: 0.04),
          offset: const Offset(0, 4),
          blurRadius: 16,
        ),
        BoxShadow(
          color: primaryTeal.withValues(alpha: 0.03),
          offset: const Offset(0, 1),
          blurRadius: 4,
        ),
      ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: warmBackground,
      primaryColor: primaryTeal,
      textTheme: GoogleFonts.cairoTextTheme().apply(
        bodyColor: darkSlate,
        displayColor: darkSlate,
      ),
    );
  }
}