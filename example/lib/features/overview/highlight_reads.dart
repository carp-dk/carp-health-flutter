/// The plugin reads behind the overview's highlights: one method per kind of read, each one plugin
/// call (plus, on Android, a `hasPermissions` check that explains an empty read).
library;

import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';

import 'model/latest_sample.dart';
import 'model/overview_windows.dart';
import 'model/sleep_summary.dart';
import 'model/workout_week.dart';

/// Reads the overview's highlights through [health]. `OverviewController` runs these and keeps their
/// results as `AsyncValue`s; each throws whatever the plugin throws.
class HighlightReads {
  /// Creates the reads of [health] on the device [capabilities] describes.
  const HighlightReads(this.health, this.capabilities);

  /// The plugin instance every call goes through.
  final Health health;

  /// The platform the reads run on.
  final PlatformCapabilities capabilities;

  /// The health platform the calls go to; Health Connect where the plugin has none, so that a read
  /// fails with the plugin's own error rather than not being made.
  HealthPlatformType get platform => capabilities.platform ?? HealthPlatformType.googleHealthConnect;

  /// Today's steps: `getTotalStepsInInterval` from midnight until now, 0 without steps.
  Future<int> stepsToday(OverviewWindows windows) => health.getTotalStepsInInterval(windows.startOfToday, windows.now);

  /// The newest data point of [type] from [since] to [until]: `limit: 1` reads only the newest page
  /// instead of the whole range (README, "Fetch health data").
  Future<LatestSample> latest(HealthDataType type, DateTime since, DateTime until) async {
    final points = await health.getHealthDataFromTypes(types: [type], startTime: since, endTime: until, limit: 1);
    if (points.isNotEmpty) return LatestSample(points.first);
    if (!capabilities.isAndroid) return const LatestSample(null);
    // Without the read permission the read returns only this app's data, without an error.
    // hasPermissions (READ by default) tells whether that is why it is empty; it costs no read quota.
    try {
      return LatestSample(null, readDenied: await health.hasPermissions([type]) == false);
    } catch (_) {
      // The check is only an explanation: when it fails, the read's result stands as no data.
      return const LatestSample(null);
    }
  }

  /// The sum of [type] from [start] to [end] in one interval, or null without data. One interval
  /// spanning the whole window gives at most one point; adding them up covers a platform that splits.
  Future<double?> sum(HealthDataType type, DateTime start, DateTime end) async {
    final points = await health.getHealthIntervalDataFromTypes(
      startDate: start,
      endDate: end,
      types: [type],
      interval: OverviewWindows.wholeWindowSeconds(start, end),
    );
    final values = [
      for (final point in points)
        if (point.value case NumericHealthValue(:final numericValue)) numericValue.toDouble(),
    ];
    return values.isEmpty ? null : values.fold<double>(0, (sum, value) => sum + value);
  }

  /// Last night: the minutes each sleep type covers from 18:00 to noon, in one interval.
  Future<SleepSummary> lastNight(OverviewWindows windows) async {
    final platform = this.platform;
    final points = await health.getHealthIntervalDataFromTypes(
      startDate: windows.nightStart,
      endDate: windows.nightEnd,
      types: SleepSummary.typesFor(platform),
      interval: OverviewWindows.wholeWindowSeconds(windows.nightStart, windows.nightEnd),
    );
    return SleepSummary.fromIntervals(points, platform);
  }

  /// The workouts since Monday: `getHealthDataFromTypes` of `WORKOUT`, every one of them, as the
  /// tile counts them and lists them on tap.
  Future<WorkoutWeek> workoutsThisWeek(OverviewWindows windows) async {
    final points = await health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: windows.startOfWeek,
      endTime: windows.now,
    );
    return WorkoutWeek(points);
  }
}
