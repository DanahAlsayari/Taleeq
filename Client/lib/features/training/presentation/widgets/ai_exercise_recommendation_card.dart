import 'package:flutter/material.dart';

import '../theme/training_theme.dart';

class AiExerciseRecommendationCard extends StatelessWidget {
  const AiExerciseRecommendationCard({
    super.key,
    required this.exerciseName,
    required this.description,
    required this.onStart,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final String exerciseName;
  final String description;
  final VoidCallback onStart;
  final bool isLoading;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrainingColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TrainingColors.mint, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: TrainingColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'التمرين المقترح لك',
                style: TrainingText.body.copyWith(
                  color: TrainingColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            exerciseName,
            style: TrainingText.exerciseTitle.copyWith(
              color: TrainingColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(description, style: TrainingText.body),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading || isDisabled ? null : onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: TrainingColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: TrainingColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'جاري تجهيز تمرينك...',
                          style: TrainingText.startButton,
                        ),
                      ],
                    )
                  : Text('ابدأ التمرين', style: TrainingText.startButton),
            ),
          ),
        ],
      ),
    );
  }
}
