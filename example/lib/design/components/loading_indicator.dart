/// The Material 3 Expressive loading indicator: a shape that keeps rotating while it morphs through a
/// sequence of expressive shapes.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import 'polygon_shapes.dart';

/// An indeterminate loading indicator that rotates while morphing through [sequence], each morph
/// bouncing into place on the fast spatial spring.
///
/// Use it wherever the app waits for the plugin. The [contained] variant sits on a circular container
/// (primary container colour) so that it stands out on busy backgrounds, such as over content while
/// pulling to refresh. The animation stops by itself when the indicator is not visible (it ticks under
/// [TickerMode], which the app shell turns off for hidden destinations).
class ExpressiveLoadingIndicator extends StatefulWidget {
  /// Creates a loading indicator.
  const ExpressiveLoadingIndicator({
    super.key,
    this.size = 48,
    this.contained = false,
    this.color,
    this.semanticsLabel = 'Loading',
  });

  /// The width and height of the indicator, including its container when [contained].
  final double size;

  /// Whether to draw the shape on a circular container.
  final bool contained;

  /// The colour of the shape; primary (or on-primary-container when [contained]) by default.
  final Color? color;

  /// What screen readers announce.
  final String semanticsLabel;

  /// The shapes the indicator morphs through, in order, before starting over.
  static const List<ExpressiveShape> sequence = [
    ExpressiveShape.softBurst,
    ExpressiveShape.cookie9,
    ExpressiveShape.pentagon,
    ExpressiveShape.pill,
    ExpressiveShape.sunny,
    ExpressiveShape.cookie4,
    ExpressiveShape.oval,
  ];

  /// How long the indicator spends on each morph.
  static const Duration morphDuration = Duration(milliseconds: 650);

  @override
  State<ExpressiveLoadingIndicator> createState() => _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator> with SingleTickerProviderStateMixin {
  // One cycle morphs through the whole sequence once.
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: ExpressiveLoadingIndicator.morphDuration * ExpressiveLoadingIndicator.sequence.length,
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? (widget.contained ? scheme.onPrimaryContainer : scheme.primary);
    Widget indicator = CustomPaint(painter: _MorphingShapePainter(_cycle, color: color));
    if (widget.contained) {
      indicator = DecoratedBox(
        decoration: ShapeDecoration(color: scheme.primaryContainer, shape: const CircleBorder()),
        child: indicator,
      );
    }
    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: SizedBox.square(dimension: widget.size, child: indicator),
      ),
    );
  }
}

/// Paints the current frame of the morphing, rotating shape.
class _MorphingShapePainter extends CustomPainter {
  _MorphingShapePainter(this.cycle, {required this.color}) : super(repaint: cycle);

  final Animation<double> cycle;
  final Color color;

  // The shape fills 38 of the indicator's 48 dp, as the Material 3 Expressive indicator does, which
  // also leaves a margin inside the container of the contained variant.
  static const double _extent = 38 / 48;

  @override
  void paint(Canvas canvas, Size size) {
    const shapes = ExpressiveLoadingIndicator.sequence;
    final position = cycle.value * shapes.length;
    final step = position.floor() % shapes.length;
    final morph = ExpressiveMotion.spatialFast.transform(position - position.floor());
    final radii = lerpRadii(shapes[step].radii, shapes[(step + 1) % shapes.length].radii, morph);
    // A steady turn per cycle plus a kick with every morph; the kicks also add up to a full turn, so the
    // rotation runs on seamlessly when the cycle repeats.
    final rotation = 2 * math.pi * cycle.value + (step + morph) * 2 * math.pi / shapes.length - math.pi / 2;
    final extent = size.shortestSide * _extent;
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: extent, height: extent);
    canvas.drawPath(polarPath(radii, rect, rotation: rotation), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MorphingShapePainter oldDelegate) => oldDelegate.color != color || oldDelegate.cycle != cycle;
}
