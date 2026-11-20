/// Last night's sleep, summed from the interval data of the sleep types: the time asleep and the time
/// in bed.
library;

import 'package:health/health.dart';

/// The sleep of one night as `getHealthIntervalDataFromTypes` reports it: for each sleep type, the
/// minutes of the night that its data covers.
///
/// The time asleep is the sum of the asleep stages ([asleepTypes]), as the Health app counts it. Apps
/// that only record whole sessions have no stages; the summary then falls back to the time in bed
/// ([inBedType]: the sleep session on Android, HealthKit's in-bed samples on iOS).
///
/// Each type's minutes count overlapping data once, but the stage types are summed here, so two apps
/// that recorded different stages of the same night count twice. The example accepts that; an app
/// would pick one source.
class SleepSummary {
  /// Creates a summary from the minutes of each sleep type.
  const SleepSummary({required this.minutesByType, required this.platform});

  /// Sums the interval [points] (one per sleep type and interval) of a night read on [platform].
  factory SleepSummary.fromIntervals(List<HealthDataPoint> points, HealthPlatformType platform) {
    final minutes = <HealthDataType, double>{};
    for (final point in points) {
      // Interval values are NumericHealthValues: here the minutes the type covers in the interval.
      if (point.value case NumericHealthValue(:final numericValue)) {
        minutes.update(point.type, (sum) => sum + numericValue, ifAbsent: () => numericValue.toDouble());
      }
    }
    return SleepSummary(minutesByType: Map.unmodifiable(minutes), platform: platform);
  }

  /// The asleep stages: unspecified sleep and the light (HealthKit's core), deep and REM stages.
  static const List<HealthDataType> asleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  /// The type that covers the time in bed on [platform]: `SLEEP_SESSION` (whole Health Connect sleep
  /// sessions) on Android, `SLEEP_IN_BED` on iOS, which has no sessions (README, "Reading data over
  /// intervals").
  static HealthDataType inBedType(HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect => HealthDataType.SLEEP_SESSION,
    HealthPlatformType.appleHealth => HealthDataType.SLEEP_IN_BED,
  };

  /// The sleep types the summary reads on [platform], in one `getHealthIntervalDataFromTypes` call.
  /// They share one permission on each platform (Health Connect's sleep sessions, HealthKit's sleep
  /// analysis), so the read needs no more access than one of them.
  static List<HealthDataType> typesFor(HealthPlatformType platform) => [inBedType(platform), ...asleepTypes];

  /// The minutes of the night each sleep type covers; types without data are missing.
  final Map<HealthDataType, double> minutesByType;

  /// The platform the night was read on.
  final HealthPlatformType platform;

  /// The minutes asleep: the sum of the [asleepTypes].
  double get asleepMinutes => asleepTypes.fold(0, (sum, type) => sum + (minutesByType[type] ?? 0));

  /// The minutes in bed ([inBedType]).
  double get inBedMinutes => minutesByType[inBedType(platform)] ?? 0;

  /// Whether the night has any sleep data.
  bool get hasData => asleepMinutes > 0 || inBedMinutes > 0;

  /// Whether the [headline] is the time asleep (the night has stages) rather than the time in bed.
  bool get showsAsleep => asleepMinutes > 0;

  /// The figure to show: the time asleep where stages exist, else the time in bed.
  Duration get headline => _duration(showsAsleep ? asleepMinutes : inBedMinutes);

  /// The time in bed, or null without session or in-bed data.
  Duration? get inBed => inBedMinutes > 0 ? _duration(inBedMinutes) : null;

  static Duration _duration(double minutes) => Duration(seconds: (minutes * 60).round());
}
