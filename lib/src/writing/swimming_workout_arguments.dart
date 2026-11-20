part of '../../health.dart';

/// The workout types of a swim, which take [SwimmingDetails] and a swimming stroke count. Health Connect has no
/// [HealthWorkoutActivityType.SWIMMING]: the workout writes reject it on Android before they get here.
const _swimmingWorkoutTypes = {
  HealthWorkoutActivityType.SWIMMING,
  HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
  HealthWorkoutActivityType.SWIMMING_POOL,
};

/// The `swimming` and `totalSwimmingStrokeCount` arguments that the workout writes send for a workout of
/// [activityType] from [start] to [end]; neither is sent when it is null.
///
/// Throws an [ArgumentError] if [swimming] or [totalSwimmingStrokeCount] is given for a workout that is not a swim, if
/// [totalSwimmingStrokeCount] is negative, or if [swimming] fails the checks of [_checkSwimmingDetails].
Map<String, dynamic> _swimmingArguments(
  HealthWorkoutActivityType activityType,
  DateTime start,
  DateTime end,
  SwimmingDetails? swimming,
  int? totalSwimmingStrokeCount,
) {
  final isSwim = _swimmingWorkoutTypes.contains(activityType);
  if (swimming != null && !isSwim) {
    throw ArgumentError.value(swimming, 'swimming', 'Only a swim has swimming details, not ${activityType.name}');
  }
  if (totalSwimmingStrokeCount != null && !isSwim) {
    throw ArgumentError.value(
      totalSwimmingStrokeCount,
      'totalSwimmingStrokeCount',
      'Only a swim has a stroke count, not ${activityType.name}',
    );
  }
  if (totalSwimmingStrokeCount != null && totalSwimmingStrokeCount < 0) {
    throw ArgumentError.value(totalSwimmingStrokeCount, 'totalSwimmingStrokeCount', 'Must not be negative');
  }
  if (swimming != null) {
    _checkSwimmingDetails(swimming, activityType, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }
  return {
    if (swimming != null)
      'swimming': {
        'poolLength': swimming.poolLength,
        'laps': [
          for (final lap in swimming.laps)
            {
              'startTime': lap.startTime.millisecondsSinceEpoch,
              'endTime': lap.endTime.millisecondsSinceEpoch,
              'strokeStyle': lap.strokeStyle.name,
            },
        ],
      },
    if (totalSwimmingStrokeCount != null) 'totalSwimmingStrokeCount': totalSwimmingStrokeCount,
  };
}

/// Throws an [ArgumentError] unless the [SwimmingDetails.poolLength] of [swimming] is null, or more than 0 and at most
/// 1000 meters for a [HealthWorkoutActivityType.SWIMMING_POOL] workout, and each of its laps starts before it ends, is
/// inside the workout from [start] to [end] (epoch milliseconds) and starts at or after the end of the lap before it.
///
/// The times are checked in the milliseconds the platform gets.
void _checkSwimmingDetails(SwimmingDetails swimming, HealthWorkoutActivityType activityType, int start, int end) {
  final poolLength = swimming.poolLength;
  // HealthKit raises an exception, which crashes the app, for a lap length without a pool location.
  if (poolLength != null && activityType != HealthWorkoutActivityType.SWIMMING_POOL) {
    throw ArgumentError.value(poolLength, 'swimming.poolLength', 'Only a SWIMMING_POOL workout has a pool length');
  }
  // Written so that NaN fails it too.
  if (poolLength != null && !(poolLength > 0 && poolLength <= 1000)) {
    throw ArgumentError.value(poolLength, 'swimming.poolLength', 'Must be more than 0 and at most 1000 meters');
  }
  var previousStart = start;
  var previousEnd = start;
  for (final (index, lap) in swimming.laps.indexed) {
    final lapStart = lap.startTime.millisecondsSinceEpoch;
    final lapEnd = lap.endTime.millisecondsSinceEpoch;
    final name = 'swimming.laps[$index]';
    if (lapStart >= lapEnd) {
      throw ArgumentError.value(lap, name, 'A lap must start before it ends');
    }
    if (lapStart < start || lapEnd > end) {
      throw ArgumentError.value(lap, name, 'A lap must be inside the workout');
    }
    if (lapStart < previousStart) {
      throw ArgumentError.value(lap, name, 'Laps must be sorted by start time');
    }
    if (lapStart < previousEnd) {
      throw ArgumentError.value(lap, name, 'Laps must not overlap');
    }
    previousStart = lapStart;
    previousEnd = lapEnd;
  }
}
