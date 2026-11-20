/// The Material 3 Expressive linear wavy progress indicator.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import 'wavy_progress_painter.dart';

/// A linear progress indicator whose active part is a travelling wave, as Material 3 Expressive shows
/// progress that is under way (for example while a read streams page after page).
///
/// With a [value] (0 to 1) it is determinate: the wave grows smoothly to each new value on the slow
/// effects spring, flattening out near 0 % and 100 %, and a stop dot marks the end of the track. Without
/// a value two wavy segments chase each other along the track. It fills the width it is given (inside a
/// `Row`, wrap it in an `Expanded`) and runs from the start side of the reading direction.
class WavyProgressIndicator extends StatefulWidget {
  /// Creates a wavy progress indicator, [height] tall (the wave's amplitude fits inside it).
  const WavyProgressIndicator({
    super.key,
    this.value,
    this.height = 12,
    this.color,
    this.trackColor,
    this.semanticsLabel,
  });

  /// The progress from 0 to 1, or null when it is not known.
  final double? value;

  /// The height of the indicator.
  final double height;

  /// The colour of the wave; primary by default.
  final Color? color;

  /// The colour of the track; secondary container by default.
  final Color? trackColor;

  /// What screen readers announce, together with the percentage when [value] is known.
  final String? semanticsLabel;

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(vsync: this, duration: WavyProgressPainter.cycle)
    ..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget paint(double? value) => CustomPaint(
      painter: WavyProgressPainter(
        animation: _cycle,
        value: value,
        color: widget.color ?? scheme.primary,
        trackColor: widget.trackColor ?? scheme.secondaryContainer,
        textDirection: Directionality.of(context),
      ),
    );

    final value = widget.value;
    const motion = ExpressiveMotion.effectsSlow;
    return Semantics(
      label: widget.semanticsLabel ?? 'Progress',
      value: value == null ? null : '${(value.clamp(0, 1) * 100).round()}%',
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: value == null
              ? paint(null)
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: value.clamp(0, 1).toDouble()),
                  duration: motion.duration,
                  curve: motion,
                  builder: (context, animated, _) => paint(animated),
                ),
        ),
      ),
    );
  }
}
