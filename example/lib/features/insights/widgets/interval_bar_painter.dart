/// Paints the Insights bar chart: a rounded expressive bar per interval on its track, value gridlines
/// with labels, time labels and a callout over the selected bar.
library;

import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import '../model/chart_axis.dart';
import '../model/insights_options.dart';

/// Where the parts of the chart go in a canvas of a given size; the painter and the tap handling
/// share it, so a tap selects the bar drawn under it.
abstract final class BarChartGeometry {
  /// The width of the value labels at the start.
  static const double axisWidth = 48;

  /// The height of the time labels at the bottom.
  static const double labelHeight = 24;

  /// The space above the plot for the selected bar's callout.
  static const double calloutSpace = 40;

  /// The rectangle the bars are drawn in.
  static Rect plotRect(Size size) =>
      Rect.fromLTRB(axisWidth, calloutSpace, size.width, math.max(calloutSpace + 1, size.height - labelHeight));

  /// The width each of [count] buckets gets.
  static double slotWidth(Size size, int count) => count == 0 ? 0 : plotRect(size).width / count;

  /// The width of a bar in a slot [slot] wide: most of the slot, so neighbours stay apart.
  static double barWidth(double slot) => (slot * 0.64).clamp(2.0, 40.0);

  /// The bucket whose slot contains [position], or null outside the plot.
  static int? indexAt(Offset position, Size size, int count) {
    final plot = plotRect(size);
    if (count == 0 || position.dx < plot.left || position.dx > plot.right) return null;
    return ((position.dx - plot.left) / slotWidth(size, count)).floor().clamp(0, count - 1);
  }
}

/// The chart's colours, from the colour scheme: primary bars on surface container tracks, the
/// selected bar in tertiary, and an inverse-surface callout.
@immutable
class BarChartColors {
  /// The colours of [scheme].
  BarChartColors.of(ColorScheme scheme)
    : bar = scheme.primary,
      selectedBar = scheme.tertiary,
      track = scheme.surfaceContainerLow,
      grid = scheme.outlineVariant,
      zeroLine = scheme.outline,
      label = scheme.onSurfaceVariant,
      callout = scheme.inverseSurface,
      onCallout = scheme.onInverseSurface;

  /// The colours of the bars, the selected bar, the tracks behind the bars, the gridlines, the zero
  /// line, the labels, and the callout and its text.
  final Color bar, selectedBar, track, grid, zeroLine, label, callout, onCallout;

  @override
  bool operator ==(Object other) =>
      other is BarChartColors &&
      other.bar == bar &&
      other.selectedBar == selectedBar &&
      other.track == track &&
      other.grid == grid &&
      other.zeroLine == zeroLine &&
      other.label == label &&
      other.callout == callout &&
      other.onCallout == onCallout;

  @override
  int get hashCode => Object.hash(bar, selectedBar, track, grid, zeroLine, label, callout, onCallout);
}

/// Paints one bar per entry of [values] (null for an interval without data, which keeps its empty
/// track) against [axis], labelled by [labels].
///
/// The bars grow in on the slow spatial spring as [grow] runs from 0 to 1, one after another from the
/// left, overshooting a little before they settle. The [selected] bar turns tertiary and its
/// [calloutText] pops up above it as [selection] runs.
class IntervalBarPainter extends CustomPainter {
  /// Creates the painter; it repaints whenever [grow] or [selection] ticks.
  IntervalBarPainter({
    required this.values,
    required this.axis,
    required this.labels,
    required this.interval,
    required this.selected,
    required this.calloutText,
    required this.grow,
    required this.selection,
    required this.colors,
    required this.labelStyle,
    required this.calloutStyle,
  }) : super(repaint: Listenable.merge([grow, selection]));

  /// The chart value of each bucket, or null without data.
  final List<double?> values;

  /// The value axis.
  final ChartAxis axis;

  /// The time label of each bucket.
  final List<String> labels;

  /// The bucket length, which decides how far apart the time labels may be.
  final InsightsInterval interval;

  /// The selected bucket, or null.
  final int? selected;

  /// The text of the selected bar's callout.
  final String? calloutText;

  /// Runs from 0 to 1 as the bars grow in.
  final Animation<double> grow;

  /// Runs from 0 to 1 when the selection changes.
  final Animation<double> selection;

  /// The colours.
  final BarChartColors colors;

  /// The style of the axis and time labels.
  final TextStyle labelStyle;

  /// The style of the callout's text.
  final TextStyle calloutStyle;

  /// How long [grow] should run: the spring plus the stagger of the last bar.
  static Duration get growDuration => ExpressiveMotion.spatialSlow.duration * (1 / (1 - _stagger));

  /// The share of [grow] by which the last bar starts after the first.
  static const double _stagger = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = BarChartGeometry.plotRect(size);
    final slot = BarChartGeometry.slotWidth(size, values.length);
    _paintGrid(canvas, plot);
    _paintBars(canvas, plot, slot);
    _paintTimeLabels(canvas, size, plot, slot);
    _paintCallout(canvas, size, plot, slot);
  }

  /// The y of [value] in [plot].
  double _y(Rect plot, double value) => plot.bottom - axis.fractionOf(value) * plot.height;

  /// The gridline and label of every tick, the zero line stronger than the others.
  void _paintGrid(Canvas canvas, Rect plot) {
    for (final tick in axis.ticks) {
      final y = _y(plot, tick);
      final paint = Paint()
        ..color = tick == 0 ? colors.zeroLine : colors.grid.withValues(alpha: 0.6)
        ..strokeWidth = tick == 0 ? 1.2 : 1;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
      final text = _text(axis.label(tick), labelStyle.copyWith(color: colors.label), BarChartGeometry.axisWidth - 8);
      text.paint(canvas, Offset(BarChartGeometry.axisWidth - 8 - text.width, y - text.height / 2));
    }
  }

  /// Each bucket's track, and its bar grown as far as [grow] has got for it.
  void _paintBars(Canvas canvas, Rect plot, double slot) {
    final width = BarChartGeometry.barWidth(slot);
    final zero = _y(plot, 0);
    final hasSelection = selected != null;
    final emphasis = ExpressiveMotion.effectsDefault.transform(selection.value.clamp(0.0, 1.0));
    for (var i = 0; i < values.length; i++) {
      final centre = plot.left + slot * (i + 0.5);
      final track = Rect.fromLTRB(centre - width / 2, plot.top, centre + width / 2, plot.bottom);
      canvas.drawRRect(RRect.fromRectAndRadius(track, Radius.circular(width / 2)), Paint()..color = colors.track);
      final value = values[i];
      if (value == null) continue;
      final top = zero + (_y(plot, value) - zero) * _growOf(i);
      // A bar of a zero value keeps a sliver, so that "0" stays apart from "no data".
      var rect = Rect.fromLTRB(track.left, math.min(top, zero), track.right, math.max(top, zero));
      if (rect.height < 3) rect = Rect.fromLTRB(rect.left, zero - 3, rect.right, zero);
      final Color color;
      if (i == selected) {
        color = Color.lerp(colors.bar, colors.selectedBar, emphasis)!;
      } else {
        color = hasSelection ? colors.bar.withValues(alpha: lerpDouble(1, 0.45, emphasis)!) : colors.bar;
      }
      canvas.drawRRect(_barShape(rect, upwards: value >= 0), Paint()..color = color);
    }
  }

  /// A bar with a fully rounded far end and slightly rounded corners on the zero line.
  RRect _barShape(Rect rect, {required bool upwards}) {
    final far = Radius.circular(math.min(rect.width / 2, rect.height / 2));
    final near = Radius.circular(math.min(ExpressiveShapes.extraSmall, rect.height / 2));
    return upwards
        ? RRect.fromRectAndCorners(rect, topLeft: far, topRight: far, bottomLeft: near, bottomRight: near)
        : RRect.fromRectAndCorners(rect, topLeft: near, topRight: near, bottomLeft: far, bottomRight: far);
  }

  /// How far bar [index] has grown: its own stretch of [grow], on the spring.
  double _growOf(int index) {
    final delay = values.length <= 1 ? 0.0 : _stagger * index / (values.length - 1);
    final local = ((grow.value - delay) / (1 - _stagger)).clamp(0.0, 1.0);
    return ExpressiveMotion.spatialSlow.transform(local);
  }

  /// The time labels under the slots, far enough apart not to overlap.
  void _paintTimeLabels(Canvas canvas, Size size, Rect plot, double slot) {
    if (values.isEmpty) return;
    final style = labelStyle.copyWith(color: colors.label);
    final widest = labels.map((label) => _text(label, style, double.infinity).width).reduce(math.max);
    final step = interval.labelStep(((widest + 8) / slot).ceil());
    for (var i = 0; i < labels.length; i += step) {
      final text = _text(labels[i], style, double.infinity);
      final centre = plot.left + slot * (i + 0.5);
      final x = clampDouble(centre - text.width / 2, 0, math.max(0, size.width - text.width));
      text.paint(canvas, Offset(x, plot.bottom + 6));
    }
  }

  /// The callout over the selected bar, popping in on the fast spatial spring.
  void _paintCallout(Canvas canvas, Size size, Rect plot, double slot) {
    final index = selected;
    final label = calloutText;
    if (index == null || label == null || index >= values.length) return;
    final text = _text(label, calloutStyle.copyWith(color: colors.onCallout), size.width - 16);
    final value = values[index];
    final barTop = value == null ? _y(plot, 0) : math.min(_y(plot, value), _y(plot, 0));
    final bubble = Size(text.width + 20, text.height + 10);
    final centre = plot.left + slot * (index + 0.5);
    final left = clampDouble(centre - bubble.width / 2, 0, math.max(0, size.width - bubble.width));
    final top = math.max(0.0, barTop - bubble.height - 6);
    final scale = ExpressiveMotion.spatialFast.transform(selection.value.clamp(0.0, 1.0));
    final anchor = Offset(clampDouble(centre, left, left + bubble.width), top + bubble.height);
    canvas
      ..save()
      ..translate(anchor.dx, anchor.dy)
      ..scale(0.6 + 0.4 * scale)
      ..translate(-anchor.dx, -anchor.dy);
    final rect = Rect.fromLTWH(left, top, bubble.width, bubble.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(bubble.height / 2)),
      Paint()..color = colors.callout,
    );
    text.paint(canvas, Offset(left + 10, top + 5));
    canvas.restore();
  }

  /// [text] laid out in [style], at most [maxWidth] wide (cut with an ellipsis).
  static TextPainter _text(String text, TextStyle style, double maxWidth) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);

  @override
  bool shouldRepaint(IntervalBarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.axis != axis ||
      oldDelegate.labels != labels ||
      oldDelegate.interval != interval ||
      oldDelegate.selected != selected ||
      oldDelegate.calloutText != calloutText ||
      oldDelegate.grow != grow ||
      oldDelegate.selection != selection ||
      oldDelegate.colors != colors ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.calloutStyle != calloutStyle;
}
