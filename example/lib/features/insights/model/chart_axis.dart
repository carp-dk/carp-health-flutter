/// The value axis of the Insights bar chart: round tick values that cover the data, and short labels
/// for them.
library;

import 'dart:math' as math;

import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';

/// A value axis from [bottom] to [top] with [ticks] at round steps; 0 is always on the axis, so bars
/// grow from a zero line (downwards for negative values, such as Health Connect's skin temperature
/// deltas).
class ChartAxis {
  const ChartAxis._(this.ticks, this.unit, {this.hasSpan = true});

  /// An axis covering [min] to [max] (and 0) with about [targetSteps] steps between ticks. Steps are
  /// 1, 2, 2.5 or 5 times a power of ten; for minutes they are whole minutes or hours, so the labels
  /// read as durations ("2 h"). Without a span (no data, or all zeros) the axis is a placeholder from 0
  /// to 1 that labels only 0 ([hasSpan] is false).
  factory ChartAxis.fit({required double min, required double max, required HealthDataUnit unit, int targetSteps = 4}) {
    final low = math.min(min, 0.0);
    final high = math.max(max, 0.0);
    final span = high - low;
    if (!span.isFinite || span <= 0) return ChartAxis._(const [0, 1], unit, hasSpan: false);
    final step = _niceStep(span / targetSteps, unit);
    final bottom = (low / step).floor();
    final top = (high / step).ceil();
    return ChartAxis._(List.unmodifiable([for (var i = bottom; i <= top; i++) i * step]), unit);
  }

  /// The tick values, ascending: the first is [bottom], the last [top].
  final List<double> ticks;

  /// The unit of the values, which decides how [label] writes them.
  final HealthDataUnit unit;

  /// Whether the axis was fitted to values; a placeholder axis has no labels but 0.
  final bool hasSpan;

  /// The lowest value on the axis: 0 unless there are negative values.
  double get bottom => ticks.first;

  /// The highest value on the axis.
  double get top => ticks.last;

  /// Where [value] lies on the axis: 0 at [bottom], 1 at [top].
  double fractionOf(double value) => (value - bottom) / (top - bottom);

  /// A short label for the tick [value], narrow enough for the axis: minutes below an hour and hours
  /// above ("45 min", "1.5 h"), a percentage, or a number. Numbers are compact on an axis that reaches
  /// ten thousand or a million, in one scale for all ticks ("5k", "10k" rather than "5,000", "10k").
  String label(double value) {
    if (value == 0) return '0';
    if (!hasSpan) return '';
    final scale = math.max(top.abs(), bottom.abs());
    return switch (unit) {
      HealthDataUnit.MINUTE when value.abs() < 60 => '${formatNumber(value, maxDecimals: 0)} min',
      HealthDataUnit.MINUTE => '${formatNumber(value / 60, maxDecimals: 1)} h',
      HealthDataUnit.PERCENT => '${formatNumber(value, maxDecimals: 1)}%',
      _ when scale >= 1e6 => '${formatNumber(value / 1e6, maxDecimals: 1)}M',
      _ when scale >= 1e4 => '${formatNumber(value / 1e3, maxDecimals: 1)}k',
      _ => formatNumber(value, maxDecimals: 3),
    };
  }

  /// Whole-minute and whole-hour steps for minute values, up to a day.
  static const List<double> _minuteSteps = [1, 2, 5, 10, 15, 20, 30, 60, 120, 180, 240, 360, 480, 720, 1440];

  /// The smallest round step of at least [raw].
  static double _niceStep(double raw, HealthDataUnit unit) {
    if (unit == HealthDataUnit.MINUTE && raw >= 1) {
      for (final step in _minuteSteps) {
        if (step >= raw) return step;
      }
      return _niceStep(raw / Duration.minutesPerDay, HealthDataUnit.NO_UNIT) * Duration.minutesPerDay;
    }
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final residual = raw / magnitude;
    final nice = residual <= 1
        ? 1
        : residual <= 2
        ? 2
        : residual <= 2.5
        ? 2.5
        : residual <= 5
        ? 5
        : 10;
    return nice * magnitude;
  }
}
