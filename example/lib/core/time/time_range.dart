/// The time ranges the example reads, writes and deletes in: quick presets and custom ranges.
library;

import 'package:health_example/core/format/formatters.dart';

/// A quick choice of time range, ending now.
enum TimeRangePreset {
  /// The last 60 minutes.
  lastHour('Last hour'),

  /// From local midnight until now.
  today('Today'),

  /// The last 24 hours.
  last24Hours('Last 24 hours'),

  /// The last 7 calendar days, today included: from midnight 6 days ago until now.
  last7Days('Last 7 days'),

  /// The last 30 calendar days, today included: from midnight 29 days ago until now.
  last30Days('Last 30 days'),

  /// A range the user picked.
  custom('Custom');

  const TimeRangePreset(this.label);

  /// The preset's display name, such as "Last 7 days".
  final String label;
}

/// A time range from [start] to [end], made from a [preset] or picked by the user.
class TimeRange {
  const TimeRange._(this.start, this.end, this.preset);

  /// The range of [preset] ending at [now] (the current time by default). The multi-day presets
  /// start at local midnight, so day intervals line up with calendar days. [TimeRangePreset.custom]
  /// has no range of its own and gives the last 24 hours, still marked custom.
  factory TimeRange.preset(TimeRangePreset preset, {DateTime? now}) {
    final end = now ?? DateTime.now();
    // Calendar arithmetic through the DateTime constructor keeps midnight right across DST changes.
    DateTime midnightDaysAgo(int days) => DateTime(end.year, end.month, end.day - days);
    final start = switch (preset) {
      TimeRangePreset.lastHour => end.subtract(const Duration(hours: 1)),
      TimeRangePreset.today => midnightDaysAgo(0),
      TimeRangePreset.last24Hours || TimeRangePreset.custom => end.subtract(const Duration(hours: 24)),
      TimeRangePreset.last7Days => midnightDaysAgo(6),
      TimeRangePreset.last30Days => midnightDaysAgo(29),
    };
    return TimeRange._(start, end, preset);
  }

  /// A custom range from [start] to [end]; the two are swapped if [end] comes first, as the
  /// plugin throws an `ArgumentError` for a start after the end.
  TimeRange.custom(DateTime start, DateTime end)
    : start = end.isBefore(start) ? end : start,
      end = end.isBefore(start) ? start : end,
      preset = TimeRangePreset.custom;

  /// The start of the range.
  final DateTime start;

  /// The end of the range.
  final DateTime end;

  /// The preset the range came from; [TimeRangePreset.custom] for picked ranges.
  final TimeRangePreset preset;

  /// The time from [start] to [end].
  Duration get duration => end.difference(start);

  /// A display name: the preset's name, or the dates and times of a custom range.
  String get label {
    if (preset != TimeRangePreset.custom) return preset.label;
    // A range of whole days, as a date range picker gives, reads better without times.
    bool atMidnight(DateTime time) => time.hour == 0 && time.minute == 0 && time.second == 0;
    if (atMidnight(start) && atMidnight(end) && start != end) {
      return '${formatDate(start)} – ${formatDate(end)}';
    }
    return formatTimeRange(start, end);
  }

  /// Whether [time] lies in the range, its ends included.
  bool contains(DateTime time) => !time.isBefore(start) && !time.isAfter(end);

  /// The same preset again, ending at [now]: for a refresh some time after the range was made.
  /// A custom range stays as it is.
  TimeRange refreshed({DateTime? now}) => preset == TimeRangePreset.custom ? this : TimeRange.preset(preset, now: now);

  @override
  bool operator ==(Object other) =>
      other is TimeRange && other.start == start && other.end == end && other.preset == preset;

  @override
  int get hashCode => Object.hash(start, end, preset);

  @override
  String toString() => 'TimeRange(${preset.name}, $start – $end)';
}
