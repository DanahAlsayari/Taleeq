
import 'package:flutter/material.dart';

class PersonalizedExerciseSuccessScreen extends StatelessWidget {
  const PersonalizedExerciseSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFAF6),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Success icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF4F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: Color(0xFF6FA7A3),
                  ),
                ),

                const SizedBox(height: 30),

                // Success title
                const Text(
                  'أحسنت!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F5F5A),
                  ),
                ),

                const SizedBox(height: 14),

                // Success message
                const Text(
                  'لقد أكملت التمرين بنجاح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E3A38),
                  ),
                ),

                const SizedBox(height: 12),

                // Encouraging message
                const Text(
                  'كل تمرين تنجزه هو خطوة نحو تحسين طلاقة حديثك. واصل تقدمك!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: Color(0xFF8FA39F),
                    height: 1.6,
                  ),
                ),

                const Spacer(),

                // Return to session
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6FA7A3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'العودة إلى الجلسة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
