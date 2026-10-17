
import 'package:flutter/material.dart';
import 'package:client/features/training/presentation/training_screen.dart';

import 'package/../../widgets/main_navigation_screen.dart';
class ExerciseSuccessScreen extends StatelessWidget {
const ExerciseSuccessScreen({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF287D78),
                size: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                'تم إكمال التمرين بنجاح!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203E3A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'أحسنت! تم حفظ نتيجتك، وتقدر تشوف تفاصيل أدائك من صفحة تقدمي.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF7A8E8B),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const MainNavigationScreen(
                            initialIndex: 3,
                            initialProgressTab: 2,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF287D78),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'عرض نتائجي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),


             const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => TrainingScreen(
                                  onStartExercise: (_) {},
                                  showBottomNav: false,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text(
                            'الرجوع إلى التمارين',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF287D78),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}