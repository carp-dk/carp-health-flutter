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
  ///    It must be equal to or later than [startTime], and on Android later
  ///    for the types listed below.
  ///    Simply set [endTime] equal to [startTime] if the [value] is measured
  ///    only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point, automatic by default.
  ///    (on iOS this must be manual or automatic)
  ///
  /// Values for Sleep and Headache are ignored and will be automatically assigned
  /// the default value. On Android each sleep value written here is a sleep
  /// session of its own: write a night with its stages with
  /// [Health.writeSleepSession].
  ///
  /// Throws an [ArgumentError] for a type with a write method of its own:
  /// [HealthDataType.WORKOUT] ([Health.writeWorkoutData]),
  /// [HealthDataType.ACTIVITY_INTENSITY] ([Health.writeActivityIntensity])
  /// and, on iOS, [HealthDataType.INSULIN_DELIVERY]
  /// ([Health.writeInsulinDelivery], which takes the delivery reason HealthKit
  /// needs) and [HealthDataType.MENSTRUATION_FLOW]
  /// ([Health.writeMenstruationFlow], which takes the start-of-cycle flag
  /// HealthKit needs). Throws a [HealthException] with
  /// [HealthErrorCode.notSupported] for a type this platform does not have,
  /// such as [HealthDataType.INSULIN_DELIVERY] on Android and
  /// [HealthDataType.TOTAL_CALORIES_BURNED] on iOS, and on iOS for
  /// [HealthDataType.SLEEP_UNKNOWN]: HealthKit has no unknown sleep value.
  /// On iOS, throws an [ArgumentError] for a type HealthKit lets apps only
  /// read, listed in [Health.requestAuthorization].
  /// Throws an [ArgumentError] if [endTime] is before [startTime]. On Android,
  /// throws a [PlatformException] with code INVALID_ARGUMENT if [endTime]
  /// equals [startTime] to the millisecond (also when it is not given) for
  /// [HealthDataType.STEPS], [HealthDataType.DISTANCE_DELTA],
  /// [HealthDataType.ACTIVE_ENERGY_BURNED],
  /// [HealthDataType.TOTAL_CALORIES_BURNED], [HealthDataType.WATER],
  /// [HealthDataType.FLIGHTS_CLIMBED], [HealthDataType.SKIN_TEMPERATURE] and
  /// the sleep types. On iOS, throws a [PlatformException] with code
  /// INVALID_ARGUMENT, before anything is saved, for a [unit] the type cannot
  /// use, a category value the type does not have, or a sample longer than
  /// HealthKit allows for the type (4 days for most types) or ending in the
  /// year 4001 or later.
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

    _checkWritable(type);
    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }
    // Read only on both platforms
    if ({HealthDataType.POWER, HealthDataType.CYCLING_CADENCE}.contains(type)) {
      throw ArgumentError("$type - writing this data type is not supported");
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
  ///    It must be equal to or later than [startTime], and on Android later
  ///    for the types listed in [writeHealthData].
  ///    Simply set [endTime] equal to [startTime] if the [value] is measured
  ///    only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point, automatic by default.
  ///    (on iOS this must be manual or automatic)
  ///
  /// Values for Sleep and Headache are ignored and will be automatically assigned
  /// the default value.
  ///
  /// Throws in the same cases as [writeHealthData].
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
    await _checkIfDataTypeAvailableOnDevice(type);
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    _checkWritable(type);

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    // Read only on both platforms
    if ({HealthDataType.POWER, HealthDataType.CYCLING_CADENCE}.contains(type)) {
      throw ArgumentError("$type - writing this data type is not supported");
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

  /// Throws for a [type] that [writeHealthData] and [writeHealthDataUUID] do
  /// not write: an [ArgumentError] for a type with a write method of its own
  /// or that HealthKit lets apps only read, and a [HealthException] with
  /// [HealthErrorCode.notSupported] for a type this platform cannot write.
  void _checkWritable(HealthDataType type) {
    if (type == HealthDataType.WORKOUT) {
      throw ArgumentError("Adding workouts should be done using the writeWorkoutData method.");
    }
    if (type == HealthDataType.ACTIVITY_INTENSITY) {
      throw ArgumentError("Adding activity intensity data should be done using the writeActivityIntensity method.");
    }
    // HealthKit raises an exception (crashing the app) for an insulin delivery without a delivery
    // reason, and for a menstrual flow without the start-of-cycle flag. Health Connect has no insulin
    // delivery (not supported below) and no such flag, so Android writes menstruation flow here too.
    if (type == HealthDataType.INSULIN_DELIVERY && platformType == HealthPlatformType.appleHealth) {
      throw ArgumentError(
        "Adding insulin delivery on iOS should be done using the writeInsulinDelivery method, "
        "which takes the delivery reason HealthKit needs.",
      );
    }
    if (type == HealthDataType.MENSTRUATION_FLOW && platformType == HealthPlatformType.appleHealth) {
      throw ArgumentError(
        "Adding menstruation flow on iOS should be done using the writeMenstruationFlow method, "
        "which takes the start-of-cycle flag HealthKit needs.",
      );
    }
    // If not implemented on platform, throw an exception
    if (!isDataTypeAvailable(type)) {
      throw HealthException(type, 'Not available on platform $platformType', errorCode: HealthErrorCode.notSupported);
    }
    // writeSleepSession keeps an unknown stage as time in bed instead.
    if (type == HealthDataType.SLEEP_UNKNOWN && platformType == HealthPlatformType.appleHealth) {
      throw HealthException(type, 'HealthKit has no unknown sleep value', errorCode: HealthErrorCode.notSupported);
    }
    if (_readOnlyTypesIOS.contains(type) && platformType == HealthPlatformType.appleHealth) {
      throw ArgumentError("$type - iOS does not support writing this data type in HealthKit");
    }
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
