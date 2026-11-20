/// What `recordingMethodsToFilter` can leave out of `getHealthIntervalDataFromTypes` on each platform
/// (README, "Filtering by recording method").
library;

import 'package:health/health.dart';

/// Whether an interval read of a type can leave out manual entries, and how to say so.
///
/// * iOS: HealthKit marks the samples a user entered by hand (`HKWasUserEntered`), and the plugin
///   leaves them out of every type's intervals when `RecordingMethod.manual` is filtered.
/// * Android: the intervals are Health Connect aggregates, which cannot be filtered by recording
///   method, except for the sleep types, whose intervals the plugin computes itself from the sleep
///   sessions. For the other types the filter is not applied: their intervals still include manual
///   entries, and the plugin prints a warning to the console.
abstract final class IntervalFiltering {
  /// The types whose intervals Health Connect reads filter by recording method: the sleep types,
  /// as in the plugin's private list.
  static const Set<HealthDataType> androidFilteredTypes = {
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_UNKNOWN,
  };

  /// The `recordingMethodsToFilter` argument for [excludeManual].
  static List<RecordingMethod> filterFor({required bool excludeManual}) =>
      excludeManual ? const [RecordingMethod.manual] : const [];

  /// Whether filtering `RecordingMethod.manual` leaves manual entries out of [type]'s intervals on
  /// [platform].
  static bool canLeaveOutManual(HealthDataType type, HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.appleHealth => true,
    HealthPlatformType.googleHealthConnect => androidFilteredTypes.contains(type),
  };

  /// What leaving out manual entries does for [type] on [platform], in a sentence.
  static String explain(HealthDataType type, HealthPlatformType platform) {
    if (platform == HealthPlatformType.appleHealth) {
      return 'Excluding manual entries leaves out the samples HealthKit marks as user entered.';
    }
    if (canLeaveOutManual(type, platform)) {
      return 'Excluding manual entries leaves out sleep sessions entered by hand.';
    }
    return "Health Connect's aggregates ignore the filter (the plugin warns on the console); only sleep "
        'types are filtered.';
  }
}
