part of '../../health.dart';

/// A stage of a sleep session written with [Health.writeSleepSession]: sleep
/// of [type] from [startTime] to [endTime].
///
/// The stages of a session must be inside it, sorted by start time and not
/// overlapping; [Health.writeSleepSession] checks them before anything is
/// written.
class SleepSessionStage {
  /// The kind of sleep in this stage: [HealthDataType.SLEEP_AWAKE],
  /// [HealthDataType.SLEEP_AWAKE_IN_BED], [HealthDataType.SLEEP_ASLEEP],
  /// [HealthDataType.SLEEP_LIGHT], [HealthDataType.SLEEP_DEEP],
  /// [HealthDataType.SLEEP_REM], [HealthDataType.SLEEP_OUT_OF_BED] or
  /// [HealthDataType.SLEEP_UNKNOWN].
  final HealthDataType type;

  /// The start of this stage. It must be before [endTime].
  final DateTime startTime;

  /// The end of this stage.
  final DateTime endTime;

  /// The types a stage can have; see [type].
  static const _types = {
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_UNKNOWN,
  };

  /// Create a stage of [type] from [startTime] to [endTime].
  const SleepSessionStage({required this.type, required this.startTime, required this.endTime});

  @override
  bool operator ==(Object other) =>
      other is SleepSessionStage && type == other.type && startTime == other.startTime && endTime == other.endTime;

  @override
  int get hashCode => Object.hash(type, startTime, endTime);

  @override
  String toString() => '$runtimeType - type: ${type.name}, startTime: $startTime, endTime: $endTime';
}
