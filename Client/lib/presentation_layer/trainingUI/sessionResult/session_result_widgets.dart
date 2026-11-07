import 'package:flutter/material.dart';

/// Colors taken from the approved result-screen design.
class ResultColors {
  ResultColors._();

  static const Color background = Color(0xFFFCFAF6);
  static const Color text = Color(0xFF203E3A);
  static const Color muted = Color(0xFF526F6A);
  static const Color subtle = Color(0xFF7A8E8B);
  static const Color border = Color(0xFFE8EFEF);
  static const Color divider = Color(0xFFD2E1E9);
  static const Color teal = Color(0xFF287D78);
  static const Color tealDark = Color(0xFF006B63);
  static const Color softTeal = Color(0xFFD8EAE7);
  static const Color track = Color(0xFFE8EEEB);
  static const Color brown = Color(0xFF8A5A2B);
  static const Color softBrown = Color(0xFFF6E8DA);
  static const Color danger = Color(0xFFA5483B);
  static const Color softDanger = Color(0xFFF7E1DC);
  static const Color infoIcon = Color(0xFF578B80);
  static const Color tipBackground = Color(0xFFF3F8F7);

  // Metric bar colors.
  static const Color fluency = Color(0xFF087F73);
  static const Color rhythm = Color(0xFF4D9BA0);
  static const Color speed = Color(0xFF527FA8);
  static const Color adherence = Color(0xFFB38B57);
  static const Color stutterTotal = Color(0xFF5FAFA8);
  static const Color block = Color(0xFFC47A50);
}

String formatPercent(double? value) =>
    value == null ? '--' : '${value.toStringAsFixed(1)}%';

String formatWholePercent(double? value) =>
    value == null ? '--' : '${value.round()}%';

String exerciseTypeLabel(String? value) {
  return switch (value) {
    'Reading' => 'القراءة',
    'Picture Description' => 'وصف صورة',
    'Free Speech' => 'الحديث الحر',
    'Question & Answer' => 'سؤال وجواب',
    'Storytelling' => 'سرد قصة',
    _ => value ?? '',
  };
}

String difficultyLabel(String? value) {
  return switch (value) {
    'Easy' => 'سهل',
    'Medium' => 'متوسط',
    'Hard' => 'متقدم',
    _ => value ?? '',
  };
}

const TextStyle _baseText = TextStyle(
  fontFamily: 'Tajawal',
  color: ResultColors.text,
);

/// White rounded card used by every section of the result screens.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor = ResultColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F203E3A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Check badge shown at the top of the session result screen.
class ResultCheckBadge extends StatelessWidget {
  const ResultCheckBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ResultColors.softTeal,
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: ResultColors.teal,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
      ),
    );
  }
}

/// "Strength" and "improvement" notes.
class ResultFeedbackText extends StatelessWidget {
  const ResultFeedbackText({super.key, this.strength, this.improvement});

  final String? strength;
  final String? improvement;

  @override
  Widget build(BuildContext context) {
    if (strength == null && improvement == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strength != null) ...[
          const _FeedbackLabel('نقطة قوة'),
          _FeedbackBody(strength!),
        ],
        if (improvement != null) ...[
          SizedBox(height: strength != null ? 10 : 0),
          const _FeedbackLabel('نقطة للتحسين'),
          _FeedbackBody(improvement!),
        ],
      ],
    );
  }
}

class _FeedbackLabel extends StatelessWidget {
  const _FeedbackLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _baseText.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _FeedbackBody extends StatelessWidget {
  const _FeedbackBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: _baseText.copyWith(
          fontSize: 13,
          height: 1.7,
          color: ResultColors.muted,
        ),
      ),
    );
  }
}

/// Card with the whole-session score and its feedback.
class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({
    super.key,
    required this.title,
    required this.score,
    this.scoreChange,
    this.strength,
    this.improvement,
  });

  final String title;
  final double? score;

  /// Difference from the previous comparable session, if there is one.
  final double? scoreChange;
  final String? strength;
  final String? improvement;

  @override
  Widget build(BuildContext context) {
    final change = scoreChange;

    return ResultCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            title,
            style: _baseText.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              formatPercent(score),
              style: _baseText.copyWith(
                fontSize: 60,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  change >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 22,
                  color: change >= 0 ? ResultColors.teal : ResultColors.danger,
                ),
                const SizedBox(width: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                    style: _baseText.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: change >= 0
                          ? ResultColors.teal
                          : ResultColors.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'مقارنة بآخر جلسة مماثلة',
                  style: _baseText.copyWith(
                    fontSize: 13,
                    color: ResultColors.muted,
                  ),
                ),
              ],
            ),
          ],
          if (strength != null || improvement != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: ResultColors.divider),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ResultFeedbackText(
                strength: strength,
                improvement: improvement,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Filled bottom button with an optional leading icon.
class ResultPrimaryButton extends StatelessWidget {
  const ResultPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ResultColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultTextButton extends StatelessWidget {
  const ResultTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ResultColors.tealDark,
          ),
        ),
      ),
    );
  }
}

/// Centered message with an optional retry button.
class ResultErrorView extends StatelessWidget {
  const ResultErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: _baseText.copyWith(fontSize: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'إعادة المحاولة',
                  style: _baseText.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ResultColors.tealDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section title with an icon and an info button.
class ResultSectionHeader extends StatelessWidget {
  const ResultSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.help,
  });

  final IconData icon;
  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 25, color: ResultColors.tealDark),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: _baseText.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: ResultColors.tealDark,
            ),
          ),
        ),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: Colors.white,
                title: Text(
                  title,
                  style: _baseText.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: Text(
                  help,
                  style: _baseText.copyWith(
                    fontSize: 14,
                    height: 1.7,
                    color: ResultColors.muted,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'حسنًا',
                      style: _baseText.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ResultColors.tealDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.info_outline_rounded,
              size: 21,
              color: ResultColors.infoIcon,
            ),
          ),
        ),
      ],
    );
  }
}

/// One metric: tinted icon, label, value and a progress bar.
class ResultMetricBar extends StatelessWidget {
  const ResultMetricBar({
    super.key,
    required this.icon,
    required this.label,
    required this.valueText,
    required this.fraction,
    required this.color,
    this.barHeight = 7,
  });

  final IconData icon;
  final String label;
  final String valueText;

  /// 0..1 fill of the bar.
  final double fraction;
  final Color color;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: _baseText.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                valueText,
                style: _baseText.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ResultProgressBar(
          fraction: fraction,
          color: color,
          height: barHeight,
        ),
      ],
    );
  }
}

class ResultProgressBar extends StatelessWidget {
  const ResultProgressBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 7,
  });

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final value = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: ResultColors.track,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Pill showing whether the technique was applied.
class TechniqueStatusPill extends StatelessWidget {
  const TechniqueStatusPill({super.key, required this.status});

  /// applied | partial | not_applied | null
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, background, foreground) = switch (status) {
      'applied' => (
        'طبّقه',
        Icons.check_circle_rounded,
        ResultColors.softTeal,
        ResultColors.tealDark,
      ),
      'partial' => (
        'طبّقه جزئيًا',
        Icons.remove_circle_rounded,
        ResultColors.softBrown,
        ResultColors.brown,
      ),
      'not_applied' => (
        'لم يطبّقه',
        Icons.cancel_rounded,
        ResultColors.softDanger,
        ResultColors.danger,
      ),
      _ => (
        'غير متاح',
        Icons.help_rounded,
        ResultColors.track,
        ResultColors.muted,
      ),
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: _baseText.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
