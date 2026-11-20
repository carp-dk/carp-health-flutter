/// The choices of an Insights read: how long each interval (bucket) is and how far back the read
/// goes, and how the chart labels the buckets of each length.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/time/time_range.dart';

/// The length of the intervals `getHealthIntervalDataFromTypes` aggregates over: its `interval`
/// argument, in [seconds].
///
/// The intervals are fixed lengths of time counted from the range's start, on both platforms
/// (HealthKit anchors its statistics there, Health Connect slices the range from there). The ranges
/// start at local midnight, so hours and days line up with the clock, except across a daylight saving
/// change, after which a day bucket starts an hour off midnight.
enum InsightsInterval {
  /// One bucket per hour: `interval: 3600`.
  hour('Hour', Icons.schedule, Duration.secondsPerHour, [1, 2, 3, 4, 6, 12]),

  /// One bucket per day: `interval: 86400`.
  day('Day', Icons.calendar_view_day, Duration.secondsPerDay, [1, 2, 3, 7, 14]),

  /// One bucket per week, counted from the range's start: `interval: 604800`.
  week('Week', Icons.calendar_view_week, 7 * Duration.secondsPerDay, [1, 2, 4]);

  const InsightsInterval(this.label, this.icon, this.seconds, this.labelSteps);

  /// The name in the button group.
  final String label;

  /// The icon in the button group.
  final IconData icon;

  /// The `interval` argument: the length of a bucket in seconds.
  final int seconds;

  /// How many buckets apart the chart may label, smallest first: steps that keep the labels on round
  /// hours or days.
  final List<int> labelSteps;

  /// The most buckets a read may have, so that every bar stays wide enough to read and to tap.
  static const int maxBuckets = 31;

  /// The interval [seconds] long, so that a read is labelled by the interval it was made with, even when
  /// the user has picked another one since; [day] for a length the app does not offer.
  static InsightsInterval ofSeconds(int seconds) =>
      values.firstWhere((interval) => interval.seconds == seconds, orElse: () => day);

  /// How many buckets [range] holds at most (its last one may be cut short by the present).
  int bucketsIn(InsightsRange range) => (range.days * Duration.secondsPerDay / seconds).ceil();

  /// Whether buckets of this length over [range] stay within [maxBuckets]: hours fit today only.
  bool fitsIn(InsightsRange range) => bucketsIn(range) <= maxBuckets;

  /// The axis label of the bucket starting at [start] in a chart of [count] buckets: the hour ("06"),
  /// the weekday ("Mon") for a week of days or less, and the date ("16 Nov") otherwise.
  String axisLabel(DateTime start, int count) => switch (this) {
    hour => start.hour.toString().padLeft(2, '0'),
    day when count <= 7 => formatWeekday(start),
    day || week => formatDate(start),
  };

  /// The bucket from [start] to [end] in words: its hours ("Today, 14:00 – 15:00"), its day ("Sun
  /// 15 Nov") or the days of its week ("9 Nov – 15 Nov"). A bucket that the present cuts short says until
  /// when it counts ("Tue 17 Nov, until 07:13").
  String describe(DateTime start, DateTime end) {
    final whole = end.difference(start).inSeconds >= seconds;
    final lastMoment = whole ? end.subtract(const Duration(milliseconds: 1)) : end;
    return switch (this) {
      hour => formatTimeRange(start, end),
      day when whole => '${formatWeekday(start)} ${formatDate(start)}',
      day => '${formatWeekday(start)} ${formatDate(start)}, until ${formatTime(end)}',
      week when whole => '${formatDate(start)} – ${formatDate(lastMoment)}',
      week => '${formatDate(start)} – ${formatDateTime(end)}',
    };
  }

  /// The step between labelled buckets: the smallest of [labelSteps] of at least [minimum], or a
  /// multiple of the largest one.
  int labelStep(int minimum) {
    for (final step in labelSteps) {
      if (step >= minimum) return step;
    }
    final largest = labelSteps.last;
    return (minimum / largest).ceil() * largest;
  }
}

/// How far back an Insights read goes: a range from local midnight [days] ago until now.
enum InsightsRange {
  /// From midnight until now.
  today('Today', TimeRangePreset.today, 1),

  /// The last 7 calendar days, today included.
  last7Days('7 days', TimeRangePreset.last7Days, 7),

  /// The last 30 calendar days, today included.
  last30Days('30 days', TimeRangePreset.last30Days, 30);

  const InsightsRange(this.label, this.preset, this.days);

  /// The name in the button group.
  final String label;

  /// The time range preset the range is made from.
  final TimeRangePreset preset;

  /// How many calendar days the range covers.
  final int days;

  /// The range ending at [now].
  TimeRange at(DateTime now) => TimeRange.preset(preset, now: now);
}
