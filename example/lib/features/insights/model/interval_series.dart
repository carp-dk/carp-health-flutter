/// One `getHealthIntervalDataFromTypes` read laid out on its time axis: a bucket for every interval
/// of the range, holding the data point the plugin returned for it, if any.
library;

import 'package:health/health.dart';
import 'package:health_example/core/format/value_formatter.dart';

import 'insights_options.dart';

/// One interval of a read, from [start] to [end], with the [point] the plugin returned for it.
///
/// The plugin returns one point per type and interval with data, and leaves out intervals without
/// data, so a bucket without [point] had no data.
class IntervalBucket {
  /// Creates bucket [index] from [start] to [end], holding [point] if the interval had data.
  const IntervalBucket({required this.index, required this.start, required this.end, this.point});

  /// The bucket's position on the time axis, from 0.
  final int index;

  /// When the interval starts.
  final DateTime start;

  /// When the interval ends: a whole interval after [start], or now for the last one.
  final DateTime end;

  /// The interval's data point, or null when the interval had no data.
  final HealthDataPoint? point;

  /// The interval's value in the type's unit: a sum for cumulative types (steps, energy, distance,
  /// water, ...), the minutes covered (sleep, mindfulness, activity intensity) or an average (any other
  /// type). Every interval point holds a `NumericHealthValue`; null without data.
  num? get value => switch (point?.value) {
    NumericHealthValue(:final numericValue) => numericValue,
    _ => null,
  };

  /// Whether the interval had data.
  bool get hasData => value != null;

  /// The apps (and on iOS devices) whose data the interval holds: the point's `sourceName` lists
  /// them, joined by ", ".
  List<String> get sources => [
    for (final source in (point?.sourceName ?? '').split(', '))
      if (source.trim().isNotEmpty) source.trim(),
  ];
}

/// The [buckets] of one interval read of [type], from [start] to [end] in steps of
/// [intervalSeconds], and the [points] the plugin returned.
class IntervalSeries {
  const IntervalSeries._({
    required this.type,
    required this.unit,
    required this.platform,
    required this.start,
    required this.end,
    required this.intervalSeconds,
    required this.buckets,
    required this.points,
    required this.unplaced,
  });

  /// Lays the interval [points] of [type], read on [platform] from [start] to [end] with
  /// `interval: intervalSeconds`, onto their buckets.
  ///
  /// A point goes to the bucket its `dateFrom` falls in, counted from [start] as the platforms count
  /// intervals (a second's leeway absorbs rounding). Points outside the range are counted in
  /// [unplaced]; none are expected.
  factory IntervalSeries.fromPoints({
    required HealthDataType type,
    required List<HealthDataPoint> points,
    required DateTime start,
    required DateTime end,
    required int intervalSeconds,
    required HealthPlatformType platform,
  }) {
    final intervalMs = intervalSeconds * Duration.millisecondsPerSecond;
    final spanMs = end.difference(start).inMilliseconds;
    final count = intervalMs <= 0 || spanMs <= 0 ? 0 : (spanMs / intervalMs).ceil();
    final placed = List<HealthDataPoint?>.filled(count, null);
    var unplaced = 0;
    for (final point in points) {
      final offsetMs = point.dateFrom.difference(start).inMilliseconds + Duration.millisecondsPerSecond;
      final index = offsetMs < 0 ? -1 : offsetMs ~/ intervalMs;
      if (index < 0 || index >= count) {
        unplaced++;
      } else {
        placed[index] = point;
      }
    }
    DateTime at(int index) => start.add(Duration(milliseconds: index * intervalMs));
    return IntervalSeries._(
      type: type,
      unit: points.isEmpty ? dataTypeToUnit[type] ?? HealthDataUnit.NO_UNIT : points.first.unit,
      platform: platform,
      start: start,
      end: end,
      intervalSeconds: intervalSeconds,
      buckets: List.unmodifiable([
        for (var i = 0; i < count; i++)
          IntervalBucket(index: i, start: at(i), end: at(i + 1).isAfter(end) ? end : at(i + 1), point: placed[i]),
      ]),
      points: List.unmodifiable(points),
      unplaced: unplaced,
    );
  }

  /// The type read.
  final HealthDataType type;

  /// The unit of the values: the plugin's unit for the type (`dataTypeToUnit`).
  final HealthDataUnit unit;

  /// The platform the read ran on, which decides how percentages are scaled.
  final HealthPlatformType platform;

  /// The start of the range read: `startDate`.
  final DateTime start;

  /// The end of the range read: `endDate`.
  final DateTime end;

  /// The length of each interval: the `interval` argument.
  final int intervalSeconds;

  /// Every interval of the range, oldest first.
  final List<IntervalBucket> buckets;

  /// The data points the plugin returned, as returned.
  final List<HealthDataPoint> points;

  /// How many of [points] fell outside the range.
  final int unplaced;

  /// The buckets that had data.
  List<IntervalBucket> get withData => [
    for (final bucket in buckets)
      if (bucket.hasData) bucket,
  ];

  /// Whether no interval had data.
  bool get isEmpty => !buckets.any((bucket) => bucket.hasData);

  /// The bucket with the highest value, or null without data.
  IntervalBucket? get peak {
    IntervalBucket? peak;
    for (final bucket in withData) {
      if (peak == null || bucket.value! > peak.value!) peak = bucket;
    }
    return peak;
  }

  /// The mean of the buckets that had data: the average per interval for sums, or a rough average of
  /// the averages. Null without data.
  double? get mean {
    final values = [for (final bucket in withData) bucket.value!];
    return values.isEmpty ? null : values.fold<double>(0, (sum, value) => sum + value) / values.length;
  }

  /// [value] as the chart plots it: HealthKit reports percentages as fractions (0.97 is 97 %), Health
  /// Connect from 0 to 100, so iOS percentages are scaled to match the value formatter.
  double chartValue(num value) =>
      unit == HealthDataUnit.PERCENT && platform == HealthPlatformType.appleHealth ? value * 100 : value.toDouble();

  /// The interval the read was made with, which labels its buckets.
  InsightsInterval get interval => InsightsInterval.ofSeconds(intervalSeconds);

  /// When [bucket] was, in words ([InsightsInterval.describe]).
  String describe(IntervalBucket bucket) => interval.describe(bucket.start, bucket.end);

  /// [value] of this read with its unit, such as "8,148 steps" or "7 h 32 min" ([formatNumericValue]).
  /// With [rounded], a figure worked out from the values (such as [mean]) is rounded to what is worth
  /// reading: whole numbers from 100 on, one decimal from 10 on.
  String format(num value, {bool rounded = false}) {
    final size = value.abs();
    final shown = !rounded || size < 10 ? value : (size >= 100 ? value.round() : (value * 10).round() / 10);
    return formatNumericValue(shown, unit, type: type, platform: platform);
  }
}
