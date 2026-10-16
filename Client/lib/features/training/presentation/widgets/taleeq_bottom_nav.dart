import 'package:flutter/material.dart';

import '../theme/training_theme.dart';
import 'taleeq_svg_icon.dart';

/// Floating bottom bar from the design.
/// Tab indexes: 0 الرئيسية, 1 التدريب, 2 التقدم, 3 الملف الشخصي.
/// Use it as `Scaffold.bottomNavigationBar` so it never overlaps the content.
class TaleeqBottomNav extends StatelessWidget {
  const TaleeqBottomNav({super.key, this.currentIndex = 1, this.onTabSelected});

  final int currentIndex;
  final ValueChanged<int>? onTabSelected;

  static const _items = [
    (label: 'الرئيسية', icon: TaleeqIcons.home),
    (label: 'التدريب', icon: TaleeqIcons.dumbbell),
    (label: 'التقدم', icon: TaleeqIcons.chart),
    (label: 'الملف الشخصي', icon: TaleeqIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TrainingColors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: TrainingColors.surface,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(color: TrainingColors.navShadow, blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == currentIndex,
                      label: _items[i].label,
                      child: InkWell(
                        onTap: () => onTabSelected?.call(i),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TaleeqSvgIcon(
                              _items[i].icon,
                              size: 24,
                              color: i == currentIndex ? TrainingColors.primary : TrainingColors.muted,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _items[i].label,
                                style: TrainingText.navLabel(
                                  i == currentIndex ? TrainingColors.primary : TrainingColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
