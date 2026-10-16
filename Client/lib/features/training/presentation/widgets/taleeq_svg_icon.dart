import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/training_theme.dart';

/// Renders the exact same stroke icons used in the design.
class TaleeqSvgIcon extends StatelessWidget {
  const TaleeqSvgIcon(
    this.paths, {
    super.key,
    this.size = 22,
    this.color = TrainingColors.text,
    this.strokeWidth = 1.9,
  });

  final String paths;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="#000000" stroke-width="$strokeWidth" stroke-linecap="round" '
      'stroke-linejoin="round">$paths</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// SVG path data of every icon used on the page (24x24 viewBox).
abstract final class TaleeqIcons {
  static const chevronDown = '<path d="M6 9l6 6 6-6"/>';
  static const chevronRight = '<path d="M9 6l6 6-6 6"/>';
  static const arrowLeft = '<path d="M19 12H5M11 6l-6 6 6 6"/>';
  static const check = '<path d="M5 12.5l4.5 4.5L19 7"/>';
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const messagesSquare =
      '<path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2z"/>'
      '<path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/>';
  static const coffee =
      '<path d="M10 2v2M14 2v2M6 2v2"/>'
      '<path d="M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a4 4 0 1 1 0 8h-1"/>';
  static const gamepad =
      '<path d="M6 11h4M8 9v4M15 12h.01M18 10h.01"/>'
      '<path d="M17.32 5H6.68a4 4 0 0 0-3.978 3.59C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258A4 4 0 0 0 17.32 5z"/>';
  static const home = '<path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z"/>';
  static const dumbbell = '<path d="M3 9v6M7 6v12M17 6v12M21 9v6M7 12h10"/>';
  static const chart = '<path d="M5 20V11M12 20V4M19 20v-6"/>';
  static const user = '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>';
}
