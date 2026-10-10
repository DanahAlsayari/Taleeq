import 'package:flutter/material.dart';

class JourneyStepper extends StatelessWidget {
  final int currentStep;

  const JourneyStepper({
    super.key,
    required this.currentStep,
  }) : assert(currentStep >= 1 && currentStep <= 4);

  static const Color _activeColor = Color(0xFF397F7A);
  static const Color _inactiveColor = Color(0xFFD9D5CC);
  static const Color _backgroundColor = Color(0xFFFCFAF6);

  static const List<String> _steps = [
    'الحساب',
    'التقييم المسبق',
    'تقييم الكلام',
    'النتائج',

  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(//the row that contains the circles and lines
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final stepBefore = index ~/ 2 + 1;
              final isCompleted = currentStep > stepBefore;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? _activeColor
                        : _inactiveColor,
                  ),
                ),
              );
            }

            final stepIndex = index ~/ 2;
            final stepNumber = stepIndex + 1;
            final isCompleted = stepNumber < currentStep;
            final isCurrent = stepNumber == currentStep;
            final isActive = stepNumber <= currentStep;

            return SizedBox(
              width: 58,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(//circle drawing
                    duration: const Duration(milliseconds: 250),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? _activeColor
                          : Colors.transparent,
                      border: Border.all(
                        color: isActive
                            ? _activeColor
                            : _inactiveColor,
                        width: isCurrent ? 2 : 1.5,
                      ),
                    ),
                    child: Center(//number or check icon inside the circle
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              '$stepNumber',
                              style: TextStyle(
                                color: isCurrent
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(//how text apear under the circle
                    _steps[stepIndex],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isCurrent
                          ? _activeColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}