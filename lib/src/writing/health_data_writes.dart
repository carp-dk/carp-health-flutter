part of '../../health.dart';

/// Part of [Health]: writing one value of a data type, such as a heart rate or
/// a weight.
// ignore: library_private_types_in_public_api
mixin HealthDataWrites on _HealthSupport {
  /// Write health data.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [value] - the health data's value in double
  ///  * [unit] - **iOS ONLY** the unit the health data is measured in.
  ///  * [type] - the value's HealthDataType
  ///  * [startTime] - the start time when this [value] is measured.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    It must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the [value] is measured
  ///    only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point, automatic by default.
  ///    (on iOS this must be manual or automatic)
  ///
  /// Values for Sleep and Headache are ignored and will be automatically assigned
  /// the default value.
  @override
  Future<bool> writeHealthData({
    required double value,
    HealthDataUnit? unit,
    required HealthDataType type,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    await _checkIfDataTypeAvailableOnDevice(type);
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    if (type == HealthDataType.WORKOUT) {
      throw ArgumentError("Adding workouts should be done using the writeWorkoutData method.");
    }
    if (type == HealthDataType.ACTIVITY_INTENSITY) {
      throw ArgumentError("Adding activity intensity data should be done using the writeActivityIntensity method.");
    }
    // If not implemented on platform, throw an exception
    if (!isDataTypeAvailable(type)) {
      throw HealthException(type, 'Not available on platform $platformType', errorCode: HealthErrorCode.notSupported);
    }
    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }
    if ({
          HealthDataType.HIGH_HEART_RATE_EVENT,
          HealthDataType.LOW_HEART_RATE_EVENT,
          HealthDataType.IRREGULAR_HEART_RATE_EVENT,
          HealthDataType.ELECTROCARDIOGRAM,
        }.contains(type) &&
        Platform.isIOS) {
      throw ArgumentError("$type - iOS does not support writing this data type in HealthKit");
    }

    // Assign default unit if not specified
    unit ??= dataTypeToUnit[type]!;

    // Align values to type in cases where the type defines the value.
    // E.g. SLEEP_IN_BED should have value 0
    if (type == HealthDataType.SLEEP_ASLEEP ||
        type == HealthDataType.SLEEP_AWAKE ||
        type == HealthDataType.SLEEP_IN_BED ||
        type == HealthDataType.SLEEP_DEEP ||
        type == HealthDataType.SLEEP_REM ||
        type == HealthDataType.SLEEP_LIGHT ||
        type == HealthDataType.HEADACHE_NOT_PRESENT ||
        type == HealthDataType.HEADACHE_MILD ||
        type == HealthDataType.HEADACHE_MODERATE ||
        type == HealthDataType.HEADACHE_SEVERE ||
        type == HealthDataType.HEADACHE_UNSPECIFIED) {
      value = _alignValue(type).toDouble();
    }

    Map<String, dynamic> args = {
      'value': value,
      'dataTypeKey': type.name,
      'dataUnitKey': unit.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };
    bool? success = await Health._channel.invokeMethod('writeData', args);
    return success ?? false;
  }

  /// Write health data and return UUID on success.
  ///
  /// Returns the UUID of the written record if successful, null otherwise.
  ///
  /// Parameters:
  ///  * [value] - the health data's value in double
  ///  * [unit] - **iOS ONLY** the unit the health data is measured in.
  ///  * [type] - the value's HealthDataType
  ///  * [startTime] - the start time when this [value] is measured.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    It must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the [value] is measured
  ///    only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point, automatic by default.
  ///    (on iOS this must be manual or automatic)
  ///
  /// Values for Sleep and Headache are ignored and will be automatically assigned
  /// the default value.
  Future<String?> writeHealthDataUUID({
    required double value,
    HealthDataUnit? unit,
    required HealthDataType type,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    if (type == HealthDataType.WORKOUT) {
      throw ArgumentError("Adding workouts should be done using the writeWorkoutData method.");
    }
    // If not implemented on platform, throw an exception
    if (!isDataTypeAvailable(type)) {
      throw HealthException(type, 'Not available on platform $platformType', errorCode: HealthErrorCode.notSupported);
    }

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    if ({
          HealthDataType.HIGH_HEART_RATE_EVENT,
          HealthDataType.LOW_HEART_RATE_EVENT,
          HealthDataType.IRREGULAR_HEART_RATE_EVENT,
          HealthDataType.ELECTROCARDIOGRAM,
        }.contains(type) &&
        Platform.isIOS) {
      throw ArgumentError("$type - iOS does not support writing this data type in HealthKit");
    }

    // Assign default unit if not specified
    unit ??= dataTypeToUnit[type]!;

    // Align values to type in cases where the type defines the value.
    // E.g. SLEEP_IN_BED should have value 0
    if (type == HealthDataType.SLEEP_ASLEEP ||
        type == HealthDataType.SLEEP_AWAKE ||
        type == HealthDataType.SLEEP_IN_BED ||
        type == HealthDataType.SLEEP_DEEP ||
        type == HealthDataType.SLEEP_REM ||
        type == HealthDataType.SLEEP_LIGHT ||
        type == HealthDataType.HEADACHE_NOT_PRESENT ||
        type == HealthDataType.HEADACHE_MILD ||
        type == HealthDataType.HEADACHE_MODERATE ||
        type == HealthDataType.HEADACHE_SEVERE ||
        type == HealthDataType.HEADACHE_UNSPECIFIED) {
      value = _alignValue(type).toDouble();
    }

    Map<String, dynamic> args = {
      'value': value,
      'dataTypeKey': type.name,
      'dataUnitKey': unit.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };

    String uuid = '${await Health._channel.invokeMethod('writeDataUUID', args)}';

    debugPrint("Added health data point: $uuid");

    return uuid;
  }

  /// Assigns numbers to specific [HealthDataType]s.
  int _alignValue(HealthDataType type) => switch (type) {
    HealthDataType.SLEEP_IN_BED => 0,
    HealthDataType.SLEEP_ASLEEP => 1,
    HealthDataType.SLEEP_AWAKE => 2,
    HealthDataType.SLEEP_LIGHT => 3,
    HealthDataType.SLEEP_DEEP => 4,
    HealthDataType.SLEEP_REM => 5,
    HealthDataType.HEADACHE_UNSPECIFIED => 0,
    HealthDataType.HEADACHE_NOT_PRESENT => 1,
    HealthDataType.HEADACHE_MILD => 2,
    HealthDataType.HEADACHE_MODERATE => 3,
    HealthDataType.HEADACHE_SEVERE => 4,
    _ => throw HealthException(
      type,
      "HealthDataType was not aligned correctly - please report bug at https://github.com/carp-dk/carp-health-flutter/issues",
    ),
  };
}
