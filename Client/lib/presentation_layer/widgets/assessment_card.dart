import 'package:flutter/material.dart';

class AssessmentCard extends StatelessWidget {
  const AssessmentCard({
    super.key,
    required this.onTap,
    required this.hasAssessment,
    this.lastAssessmentDate,
  });

  final VoidCallback onTap;
  final bool hasAssessment;
  final String? lastAssessmentDate;

  static const Color darkGreen = Color(0xFF1F5F5A);
  static const Color lightGreen = Color(0xFFEAF4F2);
  static const Color border = Color(0xFFE3EEEB);
  static const Color darkText = Color(0xFF233330);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.mic_none_rounded,
                color: darkGreen,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAssessment ? 'إعادة تقييم الكلام' : 'التقييم',
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasAssessment
                        ? 'آخر تقييم: ${lastAssessmentDate ?? '-'}'
                        : 'لم يتم إجراء التقييم بعد',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasAssessment
                        ? 'اضغط لإعادة التقييم'
                        : 'اضغط لبدء التقييم',
                    style: const TextStyle(
                      color: darkGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: darkGreen,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}