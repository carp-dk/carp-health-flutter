/// The time windows behind the overview's highlights: today, last night and this week, and how far
/// back the latest heart rate and weight are looked for.
///
/// They are plain functions of one moment ([OverviewWindows.now]), so the highlights of one load all
/// agree on what "now" is, and tests can pin it.
library;

/// The time windows of the overview's highlights, seen from [now].
///
/// Calendar arithmetic goes through the `DateTime` constructor (`DateTime(year, month, day - 1)`), which
/// keeps midnight at midnight across daylight saving changes, where subtracting 24 hours would not.
class OverviewWindows {
  /// The windows seen from [now] (the current time by default).
  OverviewWindows({DateTime? now}) : now = now ?? DateTime.now();

  /// The moment the windows end at.
  final DateTime now;

  /// The hour of the evening before from which sleep counts as last night's.
  static const int nightStartHour = 18;

  /// The hour of the day until which sleep counts as last night's.
  static const int nightEndHour = 12;

  /// How many days back the latest heart rate is looked for. Without the history permission, Health
  /// Connect reads 30 days back at most, so a longer window would only cost more calls.
  static const int heartRateDays = 30;

  /// Local midnight today, from which steps and active energy are counted.
  DateTime get startOfToday => DateTime(now.year, now.month, now.day);

  /// The start of last night: 18:00 the evening before. A sleep session that began earlier still
  /// counts with its part after this, as `getHealthIntervalDataFromTypes` counts sleep.
  DateTime get nightStart => DateTime(now.year, now.month, now.day - 1, nightStartHour);

  /// The end of last night: noon today, or now while it is still morning.
  DateTime get nightEnd {
    final noon = DateTime(now.year, now.month, now.day, nightEndHour);
    return now.isBefore(noon) ? now : noon;
  }

  /// The start of this week: Monday at midnight (weeks start on Monday, as in ISO 8601).
  DateTime get startOfWeek => DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));

  /// From when the latest heart rate is looked for: [heartRateDays] days ago.
  DateTime get heartRateSince => DateTime(now.year, now.month, now.day - heartRateDays, now.hour, now.minute);

  /// From when the latest weight is looked for: a year ago, as weight is measured rarely (the README's
  /// example of `limit`).
  DateTime get weightSince => DateTime(now.year - 1, now.month, now.day, now.hour, now.minute);

  /// The interval, in whole seconds, that makes one `getHealthIntervalDataFromTypes` bucket of the
  /// whole time from [start] to [end]: the platform then returns at most one data point per type, the
  /// sum (or the minutes, for sleep) of that time. Rounded up, so that no sliver of a second is left
  /// for a second bucket, and at least 1, as the plugin needs a positive interval.
  static int wholeWindowSeconds(DateTime start, DateTime end) {
    final seconds = (end.difference(start).inMicroseconds / Duration.microsecondsPerSecond).ceil();
    return seconds < 1 ? 1 : seconds;
  }
}
