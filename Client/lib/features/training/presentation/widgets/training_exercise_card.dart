import 'package:flutter/material.dart';

import '../../data/models/training_models.dart';
import '../theme/training_theme.dart';
import 'difficulty_dropdown.dart';
import 'taleeq_svg_icon.dart';

/// One exercise: title, description, fixed duration,
/// difficulty dropdown, and start button.
///
/// The difficulty options are displayed in an Overlay,
/// so opening them does not resize the exercise card.
class TrainingExerciseCard extends StatefulWidget {
  const TrainingExerciseCard({
    super.key,
    required this.exercise,
    required this.difficulty,
    required this.isDropdownOpen,
    required this.onToggleDropdown,
    required this.onDifficultySelected,
    required this.onStart,
  });

  final TrainingExercise exercise;
  final Difficulty difficulty;
  final bool isDropdownOpen;
  final VoidCallback onToggleDropdown;
  final ValueChanged<Difficulty> onDifficultySelected;
  final VoidCallback onStart;

  @override
  State<TrainingExerciseCard> createState() =>
      _TrainingExerciseCardState();
}

class _TrainingExerciseCardState extends State<TrainingExerciseCard> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();

  OverlayEntry? _overlayEntry;

  double _triggerWidth = 0;

  @override
  void didUpdateWidget(covariant TrainingExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDropdownOpen != oldWidget.isDropdownOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (widget.isDropdownOpen) {
          _showDropdown();
        } else {
          _removeDropdown();
        }
      });
    } else if (widget.isDropdownOpen &&
        widget.difficulty != oldWidget.difficulty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _overlayEntry?.markNeedsBuild();
      });
    }
  }

  void _handleDropdownTap() {
    widget.onToggleDropdown();
  }

  void _showDropdown() {
    _removeDropdown();

    final triggerContext = _triggerKey.currentContext;
    if (triggerContext == null) return;

    final renderBox = triggerContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    _triggerWidth = renderBox.size.width;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (widget.isDropdownOpen) {
                    widget.onToggleDropdown();
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),

            Positioned(
              width: _triggerWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 8),
                child: Material(
                  color: Colors.transparent,
                  child: DifficultyOptionsList(
                    selected: widget.difficulty,
                    onSelected: (difficulty) {
                      widget.onDifficultySelected(difficulty);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TrainingColors.exerciseCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TrainingColors.exerciseCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.exercise.titleAr,
            style: TrainingText.exerciseTitle,
          ),
          const SizedBox(height: 6),
          Text(
            widget.exercise.descriptionAr,
            style: TrainingText.body,
          ),
          const SizedBox(height: 12),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DurationBox(
                    minutes: widget.exercise.durationMinutes,
                    seconds: widget.exercise.durationSeconds,
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: Container(
                      key: _triggerKey,
                      child: DifficultyDropdownTrigger(
                        difficulty: widget.difficulty,
                        isOpen: widget.isDropdownOpen,
                        onTap: _handleDropdownTap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _StartButton(
            onTap: widget.onStart,
          ),
        ],
      ),
    );
  }
}

class _DurationBox extends StatelessWidget {
  const _DurationBox({
    required this.minutes,
    this.seconds,
  });

  final int minutes;
  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final durationText = seconds != null
        ? '$seconds ثانية'
        : '$minutes دقائق';

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: TrainingColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TrainingColors.boxBorder,
        ),
      ),
      child: Row(
        children: [
          const TaleeqSvgIcon(
            TaleeqIcons.clock,
            size: 20,
            color: TrainingColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المدة',
                    style: TrainingText.boxLabel,
                  ),
                  Text(
                    durationText,
                    style: TrainingText.boxValue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: TrainingColors.primary,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const SizedBox(width: 8),
                Text(
                  'ابدأ التمرين',
                  style: TrainingText.startButton,
                ),
                 const SizedBox(width: 8),
                  const TaleeqSvgIcon(
                  TaleeqIcons.arrowLeft,
                  size: 18,
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}