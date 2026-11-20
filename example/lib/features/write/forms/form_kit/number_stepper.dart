/// A number made smaller or larger in steps, as the audiogram editor changes its hearing thresholds.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// [value] between a minus and a plus button that change it by [step], from [min] to [max], shown by
/// [format].
///
/// The figure springs to its new value; a button is disabled at its end of the range. [label] names the
/// value for the buttons' tooltips and for screen readers, such as "left ear at 1 kHz".
class NumberStepper extends StatelessWidget {
  /// Creates a stepper for [value].
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.label,
    this.color,
  });

  /// The number shown.
  final double value;

  /// Called with the new number.
  final ValueChanged<double> onChanged;

  /// How much one tap changes [value].
  final double step;

  /// The smallest number.
  final double min;

  /// The largest number.
  final double max;

  /// The number as text, such as "25 dB".
  final String Function(double value) format;

  /// What the number is, such as "left ear at 1 kHz".
  final String label;

  /// The colour of the figure, such as the colour of an ear in the audiogram chart.
  final Color? color;

  /// [value] changed by [steps] steps, kept between [min] and [max].
  static double stepped(double value, int steps, {required double step, required double min, required double max}) =>
      (value + step * steps).clamp(min, max).toDouble();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const motion = ExpressiveMotion.spatialFast;
    final shown = format(value);
    return Semantics(
      label: label,
      value: shown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            tooltip: 'Lower $label',
            onPressed: value > min ? () => onChanged(stepped(value, -1, step: step, min: min, max: max)) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 64,
            child: AnimatedSwitcher(
              duration: motion.duration,
              switchInCurve: motion,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation.drive(Tween<double>(begin: 0.8, end: 1)),
                child: FadeTransition(opacity: animation.drive(ExpressiveMotion.clampToUnit), child: child),
              ),
              child: Text(
                shown,
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: text.titleMediumEmphasized.copyWith(color: color),
              ),
            ),
          ),
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            tooltip: 'Raise $label',
            onPressed: value < max ? () => onChanged(stepped(value, 1, step: step, min: min, max: max)) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
