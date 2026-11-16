/// Painting of the Material 3 Expressive linear wavy progress indicator.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

/// Paints a linear wavy progress indicator: the active part as a travelling sine wave, the rest of the
/// track as a flat line separated from it by a gap, and (when determinate) a stop dot at the end.
class WavyProgressPainter extends CustomPainter {
  /// Creates the painter; it repaints whenever [animation] ticks.
  WavyProgressPainter({
    required this.animation,
    required this.value,
    required this.color,
    required this.trackColor,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: animation);

  /// A repeating 0..1 animation of one [cycle]: moves the wave and the indeterminate segments.
  final Animation<double> animation;

  /// The progress from 0 to 1, or null for indeterminate progress.
  final double? value;

  /// The colour of the wave and of the stop dot.
  final Color color;

  /// The colour of the inactive track.
  final Color trackColor;

  /// The reading direction: progress runs from its start side ([TextDirection.rtl] mirrors it).
  final TextDirection textDirection;

  /// The length of one animation cycle.
  static const Duration cycle = Duration(milliseconds: 1800);

  /// Thickness of the wave and the track.
  static const double strokeWidth = 4;

  /// Length of one wave.
  static const double wavelength = 40;

  /// Space between the active wave and the track.
  static const double gap = 4;

  // The two segments of the indeterminate indicator: when their heads and tails move along the track
  // within one cycle (the timing of Material's linear indeterminate indicator).
  static const Curve _head1 = Interval(0, 750 / 1800, curve: Cubic(0.2, 0, 0.8, 1));
  static const Curve _tail1 = Interval(333 / 1800, 1083 / 1800, curve: Cubic(0.4, 0, 1, 1));
  static const Curve _head2 = Interval(1000 / 1800, 1567 / 1800, curve: Cubic(0, 0, 0.65, 1));
  static const Curve _tail2 = Interval(1267 / 1800, 1, curve: Cubic(0.1, 0, 0.45, 1));

  @override
  void paint(Canvas canvas, Size size) {
    if (textDirection == TextDirection.rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final amplitude = math.max(0.0, math.min(3.0, (size.height - strokeWidth) / 2));
    // The wave travels two wavelengths per cycle, so it runs on seamlessly when the cycle repeats.
    final phase = animation.value * 4 * math.pi;
    final progress = value;
    if (progress != null) {
      final end = progress.clamp(0.0, 1.0) * size.width;
      // The wave flattens towards 0 % and 100 %, where a wobbling stub or tail would look like a glitch.
      final ramp = _smoothStep(0, 0.1, progress) * (1 - _smoothStep(0.9, 1, progress));
      _drawWave(canvas, size, 0, end, amplitude * ramp, phase);
      if (progress < 1) {
        _drawLine(canvas, size, end + gap, size.width);
        final stop = Offset(size.width - strokeWidth / 2, size.height / 2);
        canvas.drawCircle(stop, strokeWidth / 2, Paint()..color = color);
      }
      return;
    }
    final t = animation.value;
    final segments = [
      (_tail1.transform(t) * size.width, _head1.transform(t) * size.width),
      (_tail2.transform(t) * size.width, _head2.transform(t) * size.width),
    ].where((segment) => segment.$2 - segment.$1 > 0.5).toList()..sort((a, b) => a.$1.compareTo(b.$1));
    var trackStart = 0.0;
    for (final (start, end) in segments) {
      _drawLine(canvas, size, trackStart, start - gap);
      _drawWave(canvas, size, start, end, amplitude, phase);
      trackStart = end + gap;
    }
    _drawLine(canvas, size, trackStart, size.width);
  }

  /// A flat stretch of track from [start] to [end], including its round caps.
  void _drawLine(Canvas canvas, Size size, double start, double end) {
    if (end - start < strokeWidth) return;
    final y = size.height / 2;
    canvas.drawLine(Offset(start + strokeWidth / 2, y), Offset(end - strokeWidth / 2, y), _stroke(trackColor));
  }

  /// The active wave from [start] to [end], including its round caps.
  void _drawWave(Canvas canvas, Size size, double start, double end, double amplitude, double phase) {
    if (end - start <= 0) return;
    final from = start + strokeWidth / 2;
    final to = math.max(from, end - strokeWidth / 2);
    // The wave is laid out in track coordinates, so it does not stretch as the active part grows.
    double y(double x) => size.height / 2 + amplitude * math.sin(2 * math.pi * x / wavelength - phase);
    final path = Path()..moveTo(from, y(from));
    for (var x = from + 2; x < to; x += 2) {
      path.lineTo(x, y(x));
    }
    path.lineTo(to, y(to));
    canvas.drawPath(path, _stroke(color));
  }

  Paint _stroke(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static double _smoothStep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(WavyProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.animation != animation;
}
