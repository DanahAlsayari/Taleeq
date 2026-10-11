import 'package:flutter/material.dart';

import 'signup_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF6),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 35),

                Image.asset(
                  'assets/images/taleeq_logo1.png',
                  height: 190,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 20),

                const Text(
                  'نسخة أكثر طلاقة منك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2E3A38),
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'تدريب متخصص لطلاقة الكلام بتقنية الذكاء الاصطناعي، مصمم لك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6FA7A3),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEE6D9)),
                      bottom: BorderSide(color: Color(0xFFEEE6D9)),
                    ),
                  ),
                  child: const IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.mic_rounded,
                            text: 'تقييم ذكي \n لكلامك',
                          ),
                        ),
                        VerticalDivider(color: Color(0xFFEEE6D9), width: 1),
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.psychology_rounded,
                            text: 'خطة تدريب \n مخصصة لك',
                          ),
                        ),
                        VerticalDivider(color: Color(0xFFEEE6D9), width: 1),
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.trending_up_rounded,
                            text: 'تابع تقدمك \n وتطورك',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                /*



                const FeatureCard(
                  icon: Icons.mic_rounded,
                  text: 'تقييم كلام شخصي بالذكاء الاصطناعي',
                ),

                const SizedBox(height: 12),

                const FeatureCard(
                  icon: Icons.psychology_rounded,
                  text: 'خطة تدريب مخصصة لك',
                ),

                const SizedBox(height: 12),

                const FeatureCard(
                  icon: Icons.trending_up_rounded,
                  text: 'تابع تقدمك وتطورك',
                ),
*/
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F5F5A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'إنشاء حساب',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1F5F5A),
                      side: const BorderSide(color: Color(0xFF6FA7A3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureCard({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE4EFED),
            borderRadius: BorderRadius.circular(14),
          ),

          child: Icon(icon, color: const Color(0xFF1F5F5A), size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF2E3A38),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
