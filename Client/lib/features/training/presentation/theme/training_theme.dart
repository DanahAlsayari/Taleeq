import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/training_models.dart';

/// Colours copied 1:1 from the approved design.
abstract final class TrainingColors {
  static const background = Color(0xFFF9F7F3);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1F2A2A);
  static const muted = Color(0xFF5E6B6A);
  static const primary = Color(0xFF2F7C77);
  static const primaryDark = Color(0xFF1F5C58);
  static const mint = Color(0xFFE3EFED);
  static const mintSelected = Color(0xFFEAF2F1);
  static const peach = Color(0xFFF6E8D8);
  static const exerciseCard = Color(0xFFF7F6F2);
  static const exerciseCardBorder = Color(0xFFE6E3DA);
  static const boxBorder = Color(0xFFE3E0D6);
  static const barOff = Color(0xFFD5DAD9);
  static const navShadow = Color(0x141F2A2A); // rgba(31,42,42,.08)

  static Color difficulty(Difficulty d) => switch (d) {
        Difficulty.easy => const Color(0xFF3FA66B),
        Difficulty.medium => const Color(0xFFE0A526),
        Difficulty.hard => const Color(0xFFD9534F),
      };
}

/// Text styles copied 1:1 from the design (Tajawal).
abstract final class TrainingText {
  static TextStyle _t(double size, FontWeight w, Color c, [double? height]) =>
      GoogleFonts.tajawal(fontSize: size, fontWeight: w, color: c, height: height);

  static TextStyle get screenTitle => _t(30, FontWeight.w800, TrainingColors.text);
  static TextStyle get screenSubtitle => _t(15, FontWeight.w400, TrainingColors.muted);
  static TextStyle get categoryTitle => _t(18, FontWeight.w800, TrainingColors.text);
  static TextStyle get categoryEn => _t(13, FontWeight.w400, TrainingColors.muted);
  static TextStyle get body => _t(14, FontWeight.w400, TrainingColors.muted, 1.6);
  static TextStyle get exerciseTitle => _t(17, FontWeight.w700, TrainingColors.text);
  static TextStyle get boxLabel => _t(11, FontWeight.w400, TrainingColors.muted);
  static TextStyle get boxValue => _t(15, FontWeight.w700, TrainingColors.text);
  static TextStyle option({required bool selected}) =>
      _t(15, selected ? FontWeight.w700 : FontWeight.w500, TrainingColors.text);
  static TextStyle get startButton => _t(16, FontWeight.w700, Colors.white);
  static TextStyle navLabel(Color c) => _t(11, FontWeight.w500, c);
}
