import 'package:flutter/material.dart';
import 'package:client/theme/taleeq_theme.dart';
import 'package:client/presentation_layer/trainingUI/technique_instructions_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TaleeqTheme.lightTheme,
      home: TechniqueInstructionsScreen(
        techniqueId: 1, // Easy Onset from Database
        exerciseTitle: 'تمرين القراءة',
        exerciseDescription:
            'اقرأ النص بصوت واضح، وحاول استخدام التقنية المقترحة أثناء التمرين.',
        exerciseInstructions: [
          'اختر مكانًا هادئًا ومريحًا.',
          'تأكد من عمل الميكروفون.',
          'خذ وقتك وتحدث براحة.',
        ],
      ),
    ),
  );
}