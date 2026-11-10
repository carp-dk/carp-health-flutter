part of '../../health.dart';

/// Part of [Health]: writing workouts.
// ignore: library_private_types_in_public_api
mixin HealthWorkoutWrites on _HealthSupport {
  /// Write workout data to Apple Health or Google Health Connect.
  ///
  /// Returns true if the workout data was successfully added.
  ///
  /// Parameters:
  ///  - [activityType] The type of activity performed.
  ///  - [start] The start time of the workout.
  ///  - [end] The end time of the workout.
  ///  - [totalEnergyBurned] The total energy burned during the workout.
  ///  - [totalEnergyBurnedUnit] The UNIT used to measure [totalEnergyBurned]
  ///    *ONLY FOR IOS* Default value is KILOCALORIE.
  ///  - [totalDistance] The total distance traveled during the workout.
  ///  - [totalDistanceUnit] The UNIT used to measure [totalDistance]
  ///    *ONLY FOR IOS* Default value is METER.
  ///  - [title] The title of the workout.
  ///    *ONLY FOR HEALTH CONNECT* Default value is the [activityType], e.g. "STRENGTH_TRAINING".
  ///  - [metadata] HealthKit metadata of the workout, such as its brand name or whether it was done indoors.
  ///    *ONLY FOR IOS* Ignored on Android. See [WorkoutMetadata].
  ///  - [recordingMethod] The recording method of the data point, automatic by default (on iOS this can only be automatic or manual).
  ///
  /// Throws a [HealthException] with [HealthErrorCode.notSupported] for an [activityType] this platform has no
  /// workout type for, such as [HealthWorkoutActivityType.ARCHERY] on Android.
  Future<bool> writeWorkoutData({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalEnergyBurned,
    HealthDataUnit totalEnergyBurnedUnit = HealthDataUnit.KILOCALORIE,
    int? totalDistance,
    HealthDataUnit totalDistanceUnit = HealthDataUnit.METER,
    String? title,
    WorkoutMetadata? metadata,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    _checkWorkoutActivityType(activityType);
    final args = <String, dynamic>{
      'activityType': activityType.name,
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
      'totalEnergyBurned': totalEnergyBurned,
      'totalEnergyBurnedUnit': totalEnergyBurnedUnit.name,
      'totalDistance': totalDistance,
      'totalDistanceUnit': totalDistanceUnit.name,
      'title': title,
      'recordingMethod': recordingMethod.toInt(),
      if (metadata != null) 'metadata': metadata.toJson(),
    };
    return await Health._channel.invokeMethod('writeWorkoutData', args) == true;
  }

  /// Write workout data to Apple Health or Google Health Connect and return UUID.
  ///
  /// Returns UUID if the workout data was successfully added, null otherwise.
  ///
  /// Parameters:
  ///  - [activityType] The type of activity performed.
  ///  - [start] The start time of the workout.
  ///  - [end] The end time of the workout.
  ///  - [totalEnergyBurned] The total energy burned during the workout.
  ///  - [totalEnergyBurnedUnit] The UNIT used to measure [totalEnergyBurned]
  ///    *ONLY FOR IOS* Default value is KILOCALORIE.
  ///  - [totalDistance] The total distance traveled during the workout.
  ///  - [totalDistanceUnit] The UNIT used to measure [totalDistance]
  ///    *ONLY FOR IOS* Default value is METER.
  ///  - [title] The title of the workout.
  ///    *ONLY FOR HEALTH CONNECT* Default value is the [activityType], e.g. "STRENGTH_TRAINING".
  ///  - [metadata] HealthKit metadata of the workout, such as its brand name or whether it was done indoors.
  ///    *ONLY FOR IOS* Ignored on Android. See [WorkoutMetadata].
  ///  - [recordingMethod] The recording method of the data point, automatic by default (on iOS this can only be automatic or manual).
  ///
  /// Throws a [HealthException] with [HealthErrorCode.notSupported] for an [activityType] this platform has no
  /// workout type for, such as [HealthWorkoutActivityType.ARCHERY] on Android.
  Future<String?> writeWorkoutDataUUID({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalEnergyBurned,
    HealthDataUnit totalEnergyBurnedUnit = HealthDataUnit.KILOCALORIE,
    int? totalDistance,
    HealthDataUnit totalDistanceUnit = HealthDataUnit.METER,
    String? title,
    WorkoutMetadata? metadata,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    _checkWorkoutActivityType(activityType);
    final args = <String, dynamic>{
      'activityType': activityType.name,
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
      'totalEnergyBurned': totalEnergyBurned,
      'totalEnergyBurnedUnit': totalEnergyBurnedUnit.name,
      'totalDistance': totalDistance,
      'totalDistanceUnit': totalDistanceUnit.name,
      'title': title,
      'recordingMethod': recordingMethod.toInt(),
      if (metadata != null) 'metadata': metadata.toJson(),
    };

    String uuid = '${await Health._channel.invokeMethod('writeWorkoutDataUUID', args)}';

    debugPrint("Added workout data point: $uuid");

    return uuid;
  }

  /// Throws a [HealthException] with [HealthErrorCode.notSupported] if this platform has no workout type for
  /// [activityType].
  void _checkWorkoutActivityType(HealthWorkoutActivityType activityType) {
    final (supported, platform) = platformType == HealthPlatformType.appleHealth
        ? (_isOnIOS(activityType), 'iOS')
        : (_isOnAndroid(activityType), 'Android');
    if (!supported) {
      throw HealthException(
        activityType,
        "Workout activity type $activityType is not supported on $platform",
        errorCode: HealthErrorCode.notSupported,
      );
    }
  }
}
