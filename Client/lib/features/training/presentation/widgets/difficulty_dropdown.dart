import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/training_models.dart';
import '../theme/training_theme.dart';
import 'taleeq_svg_icon.dart';

/// The three ascending bars that show the level (colour depends on the level).
class DifficultyBars extends StatelessWidget {
  const DifficultyBars({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final on = TrainingColors.difficulty(difficulty);
    const heights = [8.0, 13.0, 18.0];
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Container(
              width: 4,
              height: heights[i],
              decoration: BoxDecoration(
                color: i < difficulty.bars ? on : TrainingColors.barOff,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The "مستوى الصعوبة" box. Tapping it opens [DifficultyOptionsList].
class DifficultyDropdownTrigger extends StatelessWidget {
  const DifficultyDropdownTrigger({
    super.key,
    required this.difficulty,
    required this.isOpen,
    required this.onTap,
  });

  final Difficulty difficulty;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: isOpen,
      label: 'اختر مستوى الصعوبة',
      child: Material(
        color: TrainingColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isOpen ? TrainingColors.primary : TrainingColors.boxBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  DifficultyBars(difficulty: difficulty),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مستوى الصعوبة', style: TrainingText.boxLabel),
                          Text(difficulty.labelAr, style: TrainingText.boxValue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Transform.rotate(
                    angle: isOpen ? math.pi : 0,
                    child: const TaleeqSvgIcon(
                      TaleeqIcons.chevronDown,
                      size: 18,
                      color: TrainingColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The list with the three levels. Nothing is locked: every level is tappable.
class DifficultyOptionsList extends StatelessWidget {
  const DifficultyOptionsList({super.key, required this.selected, required this.onSelected});

  final Difficulty selected;
  final ValueChanged<Difficulty> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TrainingColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TrainingColors.boxBorder),
      ),
      child: Column(
        children: [
          for (final d in Difficulty.values)
            _OptionTile(
              difficulty: d,
              isSelected: d == selected,
              onTap: () => onSelected(d),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.difficulty, required this.isSelected, required this.onTap});

  final Difficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? TrainingColors.mintSelected : TrainingColors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  DifficultyBars(difficulty: difficulty),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(difficulty.labelAr, style: TrainingText.option(selected: isSelected)),
                  ),
                  if (isSelected)
                    const TaleeqSvgIcon(
                      TaleeqIcons.check,
                      size: 18,
                      color: TrainingColors.primary,
                      strokeWidth: 2.4,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
