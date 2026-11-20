/// The Audiogram form's chart of the audiogram being edited.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'audiogram_points.dart';

/// [points] drawn as a clinical audiogram: frequency on a logarithmic axis from 125 Hz to 8 kHz, the
/// hearing threshold growing downwards (lower is worse hearing), the right ear as circles and the left
/// ear as crosses joined by lines, over a band that marks normal hearing. Edited thresholds spring into
/// place.
class AudiogramChart extends StatelessWidget {
  /// Creates the chart of [points].
  const AudiogramChart({super.key, required this.points, this.height = 220});

  /// The tested frequencies and their thresholds, in ascending frequency.
  final List<AudiogramPoint> points;

  /// The height of the chart.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final _ChartColors colors = (
      left: scheme.primary,
      right: scheme.tertiary,
      grid: scheme.outlineVariant,
      band: scheme.secondaryContainer,
      label: scheme.onSurfaceVariant,
      surface: scheme.surfaceContainerLow,
    );
    const motion = ExpressiveMotion.spatialDefault;
    final legend = theme.textTheme.labelMedium!.copyWith(color: colors.label);
    Widget key(Widget marker, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        marker,
        Text(text, style: legend),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Semantics(
          label: 'Audiogram of ${points.length} frequencies',
          child: SizedBox(
            height: height,
            child: TweenAnimationBuilder<List<AudiogramPoint>>(
              tween: _PointsTween(end: points),
              duration: motion.duration,
              curve: motion,
              builder: (context, shown, _) => CustomPaint(
                size: Size.infinite,
                painter: _AudiogramPainter(shown, colors, theme.textTheme.labelSmall!.copyWith(color: colors.label)),
              ),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            key(Icon(Icons.circle_outlined, size: 16, color: colors.right), 'Right ear'),
            key(Icon(Icons.close, size: 16, color: colors.left), 'Left ear'),
            key(
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.band,
                  shape: ExpressiveShapes.rounded(ExpressiveShapes.extraSmall),
                ),
                child: const SizedBox(width: 16, height: 12),
              ),
              'Normal (≤ 20 dB)',
            ),
          ],
        ),
      ],
    );
  }
}

/// Interpolates the thresholds of two audiograms with the same frequencies; another set of frequencies
/// is shown at once.
class _PointsTween extends Tween<List<AudiogramPoint>> {
  _PointsTween({required super.end});

  @override
  List<AudiogramPoint> lerp(double t) {
    final from = begin, to = end!;
    if (from == null || from.length != to.length) return to;
    return [
      for (var i = 0; i < to.length; i++)
        from[i].frequency != to[i].frequency
            ? to[i]
            : AudiogramPoint(
                to[i].frequency,
                left: lerpDouble(from[i].left, to[i].left, t)!,
                right: lerpDouble(from[i].right, to[i].right, t)!,
              ),
    ];
  }
}

/// The colours of the chart, from the theme: each ear's, the grid's, the normal band's, the labels' and
/// the surface the circles are filled with. A record, so that equal colours compare equal.
typedef _ChartColors = ({Color left, Color right, Color grid, Color band, Color label, Color surface});

/// Paints the grid, the normal band and each ear's thresholds.
class _AudiogramPainter extends CustomPainter {
  _AudiogramPainter(this.points, this.colors, this.labelStyle);

  final List<AudiogramPoint> points;
  final _ChartColors colors;
  final TextStyle labelStyle;

  static const double _lowest = 125, _highest = 8000;
  static const List<double> _octaves = [125, 250, 500, 1000, 2000, 4000, 8000];

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTRB(40, 10, size.width - 12, size.height - 22);
    // The scale covers -10 to 120 dB HL, the range of a clinical audiogram, and grows for thresholds outside it.
    final values = [
      for (final point in points) ...[point.left, point.right],
    ];
    final minDb = math.min(-10.0, ((values.isEmpty ? 0 : values.reduce(math.min)) / 10).floor() * 10.0);
    final maxDb = math.max(120.0, ((values.isEmpty ? 0 : values.reduce(math.max)) / 10).ceil() * 10.0);
    double x(double frequency) {
      final octaves = math.log(frequency.clamp(_lowest, _highest) / _lowest) / math.ln2;
      return chart.left + octaves / (math.log(_highest / _lowest) / math.ln2) * chart.width;
    }

    double y(double db) => chart.top + (db - minDb) / (maxDb - minDb) * chart.height;

    final band = Rect.fromLTRB(chart.left, chart.top, chart.right, y(AudiogramPlan.normalLimit));
    canvas.drawRRect(RRect.fromRectAndRadius(band, const Radius.circular(8)), Paint()..color = colors.band);
    final grid = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (var db = (minDb / 20).ceil() * 20.0; db <= maxDb; db += 20) {
      canvas.drawLine(Offset(chart.left, y(db)), Offset(chart.right, y(db)), grid);
      _label(canvas, '${db.round()}', Offset(chart.left - 6, y(db)), Alignment.centerRight);
    }
    for (final frequency in _octaves) {
      canvas.drawLine(Offset(x(frequency), chart.top), Offset(x(frequency), chart.bottom), grid);
      final text = frequency >= 1000 ? '${(frequency / 1000).round()}k' : '${frequency.round()}';
      _label(canvas, text, Offset(x(frequency), chart.bottom + 6), Alignment.topCenter);
    }
    for (final ear in Ear.values) {
      final color = ear == Ear.left ? colors.left : colors.right;
      final offsets = [for (final point in points) Offset(x(point.frequency), y(point.of(ear)))];
      final stroke = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (offsets.length > 1) canvas.drawPath(Path()..addPolygon(offsets, false), stroke);
      for (final offset in offsets) {
        if (ear == Ear.right) {
          canvas.drawCircle(offset, 6, Paint()..color = colors.surface);
          canvas.drawCircle(offset, 6, stroke);
        } else {
          canvas.drawLine(offset + const Offset(-5, -5), offset + const Offset(5, 5), stroke);
          canvas.drawLine(offset + const Offset(-5, 5), offset + const Offset(5, -5), stroke);
        }
      }
    }
  }

  /// Paints [text] at [anchor], aligned to it by [alignment].
  void _label(Canvas canvas, String text, Offset anchor, Alignment alignment) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, anchor - alignment.alongSize(painter.size));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_AudiogramPainter old) =>
      !listEquals(old.points, points) || old.colors != colors || old.labelStyle != labelStyle;
}
