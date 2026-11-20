/// A drawing of an electrocardiogram's voltage over time.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// Draws the first [window] of an ECG's [voltages] as a trace across the width it is given.
///
/// An Apple Watch ECG has about 15,000 samples over 30 seconds, more than there are pixels. The trace
/// keeps the lowest and highest voltage of each pixel column, so the sharp peaks of the heartbeats stay
/// visible however much is drawn.
class EcgTrace extends StatelessWidget {
  /// Creates a trace of [voltages].
  const EcgTrace({super.key, required this.voltages, this.window = const Duration(seconds: 6), this.color});

  /// The samples, in order of [ElectrocardiogramVoltageValue.timeSinceSampleStart] (in seconds).
  final List<ElectrocardiogramVoltageValue> voltages;

  /// How much of the recording to draw, from its start.
  final Duration window;

  /// The colour of the trace; the primary colour by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seconds = window.inMicroseconds / Duration.microsecondsPerSecond;
    final samples = voltages.where((sample) => sample.timeSinceSampleStart <= seconds).toList();
    return Semantics(
      label: 'ECG trace of the first ${window.inSeconds} seconds',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _EcgPainter(samples, seconds, color ?? scheme.primary, scheme.outlineVariant),
        ),
      ),
    );
  }
}

/// Paints the [samples] of the first [seconds] as a trace in [color] over a faint line per second in
/// [gridColor], scaled to fill the canvas from the lowest to the highest voltage.
class _EcgPainter extends CustomPainter {
  _EcgPainter(this.samples, this.seconds, this.color, this.gridColor);

  final List<ElectrocardiogramVoltageValue> samples;
  final double seconds;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    // A faint line every second, as on ECG paper.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var second = 1; second < seconds; second++) {
      final x = size.width * second / seconds;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    if (samples.length < 2 || size.width < 1) return;

    final columns = size.width.floor();
    final lows = List<double?>.filled(columns, null);
    final highs = List<double?>.filled(columns, null);
    var minimum = double.infinity, maximum = double.negativeInfinity;
    for (final sample in samples) {
      final column = math.min(columns - 1, (sample.timeSinceSampleStart / seconds * columns).floor());
      final voltage = sample.voltage.toDouble();
      lows[column] = math.min(lows[column] ?? voltage, voltage);
      highs[column] = math.max(highs[column] ?? voltage, voltage);
      minimum = math.min(minimum, voltage);
      maximum = math.max(maximum, voltage);
    }
    final range = maximum - minimum == 0 ? 1 : maximum - minimum;
    double y(double voltage) => size.height - 4 - (voltage - minimum) / range * (size.height - 8);

    final path = Path();
    var started = false;
    for (var column = 0; column < columns; column++) {
      final low = lows[column], high = highs[column];
      if (low == null || high == null) continue;
      if (!started) {
        path.moveTo(column.toDouble(), y(low));
        started = true;
      }
      path
        ..lineTo(column.toDouble(), y(low))
        ..lineTo(column.toDouble(), y(high));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_EcgPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.color != color || oldDelegate.seconds != seconds;
}
