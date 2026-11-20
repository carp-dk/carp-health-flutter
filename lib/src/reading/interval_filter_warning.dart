part of '../../health.dart';

/// The types whose intervals Android filters by recording method: the sleep
/// types, whose intervals the plugin sums from sleep sessions. The intervals of
/// every other type are Health Connect aggregates, which include data of every
/// recording method.
const _sleepIntervalTypes = {
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

/// Prints a warning for the part of [filter] that the intervals of [types]
/// cannot apply on [platform]: on Android for the types other than sleep, on
/// iOS for the recording methods other than [RecordingMethod.manual]. That data
/// is not left out.
void _warnUnfilteredIntervals(HealthPlatformType platform, List<HealthDataType> types, List<RecordingMethod> filter) {
  if (filter.isEmpty) return;
  final methods = filter.map((method) => method.name).join(', ');
  if (platform == HealthPlatformType.googleHealthConnect) {
    final unfiltered = [
      for (final type in types)
        if (!_sleepIntervalTypes.contains(type)) type.name,
    ];
    if (unfiltered.isEmpty) return;
    debugPrint(
      'Health: getHealthIntervalDataFromTypes cannot leave out recording methods ($methods) for '
      '${unfiltered.join(', ')} on Android: their intervals are Health Connect aggregates, which include '
      'data of every recording method. recordingMethodsToFilter applies to the sleep types only.',
    );
  } else {
    final ignored = [
      for (final method in filter)
        if (method != RecordingMethod.manual) method.name,
    ];
    if (ignored.isEmpty) return;
    debugPrint(
      'Health: getHealthIntervalDataFromTypes cannot leave out ${ignored.join(', ')} on iOS: HealthKit marks '
      'only the samples the user entered, so only RecordingMethod.manual can be filtered out.',
    );
  }
}
