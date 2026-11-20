/// A duration made shorter or longer in steps, as the lap and sleep stage editors change theirs.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';

/// [value] between a minus and a plus button that change it by [step], from [min] to [max].
///
/// The figure springs to its new value; a button is disabled at its end of the range.
class DurationStepper extends StatelessWidget {
  /// Creates a stepper for [value].
  const DurationStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.step,
    required this.min,
    required this.max,
    this.label = 'duration',
    this.large = false,
  });

  /// The duration shown.
  final Duration value;

  /// Called with the new duration.
  final ValueChanged<Duration> onChanged;

  /// How much one tap changes [value].
  final Duration step;

  /// The shortest duration.
  final Duration min;

  /// The longest duration.
  final Duration max;

  /// What the duration is, for the buttons' tooltips, such as "lap 2".
  final String label;

  /// Whether to show the figure in a large emphasized style, as the main value of an editor.
  final bool large;

  /// [value] changed by [steps] steps, kept between [min] and [max].
  static Duration stepped(
    Duration value,
    int steps, {
    required Duration step,
    required Duration min,
    required Duration max,
  }) {
    final next = value + step * steps;
    if (next < min) return min;
    if (next > max) return max;
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const motion = ExpressiveMotion.spatialFast;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        IconButton.filledTonal(
          tooltip: 'Shorter $label',
          onPressed: value > min ? () => onChanged(stepped(value, -1, step: step, min: min, max: max)) : null,
          icon: const Icon(Icons.remove),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: large ? 112 : 72),
          child: AnimatedSwitcher(
            duration: motion.duration,
            switchInCurve: motion,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation.drive(Tween<double>(begin: 0.8, end: 1)),
              child: FadeTransition(opacity: animation.drive(ExpressiveMotion.clampToUnit), child: child),
            ),
            child: Text(
              formatDuration(value),
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: (large ? text.headlineSmallEmphasized : text.titleMediumEmphasized).tabular,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Longer $label',
          onPressed: value < max ? () => onChanged(stepped(value, 1, step: step, min: min, max: max)) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
