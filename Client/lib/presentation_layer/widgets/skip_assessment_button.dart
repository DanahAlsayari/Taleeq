
import 'package:flutter/material.dart';

class SkipAssessmentButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SkipAssessmentButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6F8580),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 25,
        ),
      ),
 
child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Text(
      'المتابعة لاحقًا',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF6F8580),
        decoration: TextDecoration.none,
      ),
    ),
    const SizedBox(height: 0),
    Container(
      height: 1,
      width: 90,
      color: const Color(0xFF6F8580),
    ),
  ],
),

    );
  }
}
