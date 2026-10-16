import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/training_models.dart';
import '../theme/training_theme.dart';
import 'taleeq_svg_icon.dart';

/// Expandable category (accordion item). The exercise cards are passed in
/// as [exercises] so this widget stays presentation-only.
class TrainingCategoryCard extends StatelessWidget {
  const TrainingCategoryCard({
    super.key,
    required this.category,
    required this.isExpanded,
    required this.onToggle,
    required this.exercises,
  });

  final TrainingCategory category;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> exercises;

  String get _iconPaths => switch (category.kind) {
        TrainingCategoryKind.speechPractice => TaleeqIcons.messagesSquare,
        TrainingCategoryKind.realLifeScenarios => TaleeqIcons.coffee,
        TrainingCategoryKind.speakingGames => TaleeqIcons.gamepad,
      };

  Color get _iconBackground => category.kind == TrainingCategoryKind.realLifeScenarios
      ? TrainingColors.peach
      : TrainingColors.mint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrainingColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: isExpanded,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _iconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: TaleeqSvgIcon(
                      _iconPaths,
                      size: 26,
                      color: TrainingColors.primary,
                      strokeWidth: 1.8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.titleAr, style: TrainingText.categoryTitle),
                        Text(category.titleEn, style: TrainingText.categoryEn),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: isExpanded ? math.pi : 0,
                    child: const TaleeqSvgIcon(TaleeqIcons.chevronDown, size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(category.descriptionAr, style: TrainingText.body),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < exercises.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              exercises[i],
            ],
          ],
        ],
      ),
    );
  }
}
