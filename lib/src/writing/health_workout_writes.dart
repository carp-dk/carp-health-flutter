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
  ///  - [clientRecordId] Your id of the workout, to write it again without adding a copy (see below).
  ///    *ONLY FOR HEALTH CONNECT* Ignored on iOS, where [WorkoutMetadata.syncIdentifier] does this.
  ///  - [clientRecordVersion] The version of the workout with [clientRecordId].
  ///    *ONLY FOR HEALTH CONNECT* Ignored on iOS.
  ///  - [startZoneOffset] and [endZoneOffset] The offsets from UTC of the local time at the start and at the end
  ///    of the workout, at most 18 hours either way; without them the records get Health Connect's default.
  ///    *ONLY FOR HEALTH CONNECT* Ignored on iOS.
  ///  - [swimming] The pool length and laps of a [HealthWorkoutActivityType.SWIMMING_POOL] or
  ///    [HealthWorkoutActivityType.SWIMMING_OPEN_WATER] workout, or on iOS a [HealthWorkoutActivityType.SWIMMING] one;
  ///    the pool length only for SWIMMING_POOL. [SwimmingDetails] says what each platform stores and reads back.
  ///  - [totalSwimmingStrokeCount] The number of strokes of a swim, HealthKit's total for the workout, which reads back
  ///    as [WorkoutHealthValue.totalSwimmingStrokeCount].
  ///    *ONLY FOR IOS* Ignored on Android: Health Connect has no record of strokes.
  ///
  /// A workout written with the [clientRecordId] (on iOS the [WorkoutMetadata.syncIdentifier]) of a workout
  /// this app wrote before replaces that workout if its version is greater, and is not added as a copy. On
  /// Android, the workout's distance and energy burned are records of their own, with the client record ids
  /// `<clientRecordId>:distance` and `<clientRecordId>:calories`: a rewrite without a distance or energy keeps
  /// the one written before. Delete them with [Health.deleteByClientRecordId] for [HealthDataType.WORKOUT],
  /// [HealthDataType.DISTANCE_DELTA] and [HealthDataType.TOTAL_CALORIES_BURNED].
  ///
  /// Throws an [ArgumentError], before anything is written, if only one of [clientRecordId] and
  /// [clientRecordVersion] is given, or only one of [WorkoutMetadata.syncIdentifier] and
  /// [WorkoutMetadata.syncVersion], or a zone offset of more than 18 hours; if [swimming] or
  /// [totalSwimmingStrokeCount] is given for a workout that is not a swim, or [totalSwimmingStrokeCount] is negative;
  /// if a [SwimmingDetails.poolLength] is given for a workout that is not a SWIMMING_POOL, or is not more than 0 and
  /// at most 1000 meters; or if a lap does not start before it ends, is not inside the workout, starts before the lap
  /// before it or overlaps it. Throws a [HealthException] with [HealthErrorCode.notSupported] for an [activityType]
  /// this platform has no workout type for, such as [HealthWorkoutActivityType.ARCHERY] on Android.
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
    String? clientRecordId,
    double? clientRecordVersion,
    Duration? startZoneOffset,
    Duration? endZoneOffset,
    SwimmingDetails? swimming,
    int? totalSwimmingStrokeCount,
  }) async {
    final args = await _workoutArguments(
      activityType: activityType,
      start: start,
      end: end,
      totalEnergyBurned: totalEnergyBurned,
      totalEnergyBurnedUnit: totalEnergyBurnedUnit,
      totalDistance: totalDistance,
      totalDistanceUnit: totalDistanceUnit,
      title: title,
      metadata: metadata,
      recordingMethod: recordingMethod,
      clientRecordId: clientRecordId,
      clientRecordVersion: clientRecordVersion,
      startZoneOffset: startZoneOffset,
      endZoneOffset: endZoneOffset,
      swimming: swimming,
      totalSwimmingStrokeCount: totalSwimmingStrokeCount,
    );
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
  ///  - [clientRecordId], [clientRecordVersion], [startZoneOffset] and [endZoneOffset] As in [writeWorkoutData],
  ///    which says how to write a workout again without adding a copy.
  ///    *ONLY FOR HEALTH CONNECT* Ignored on iOS.
  ///  - [swimming] The pool length and laps of a swim, as in [writeWorkoutData]. See [SwimmingDetails].
  ///  - [totalSwimmingStrokeCount] The number of strokes of a swim, as in [writeWorkoutData].
  ///    *ONLY FOR IOS* Ignored on Android.
  ///
  /// Throws what [writeWorkoutData] throws.
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
    String? clientRecordId,
    double? clientRecordVersion,
    Duration? startZoneOffset,
    Duration? endZoneOffset,
    SwimmingDetails? swimming,
    int? totalSwimmingStrokeCount,
  }) async {
    final args = await _workoutArguments(
      activityType: activityType,
      start: start,
      end: end,
      totalEnergyBurned: totalEnergyBurned,
      totalEnergyBurnedUnit: totalEnergyBurnedUnit,
      totalDistance: totalDistance,
      totalDistanceUnit: totalDistanceUnit,
      title: title,
      metadata: metadata,
      recordingMethod: recordingMethod,
      clientRecordId: clientRecordId,
      clientRecordVersion: clientRecordVersion,
      startZoneOffset: startZoneOffset,
      endZoneOffset: endZoneOffset,
      swimming: swimming,
      totalSwimmingStrokeCount: totalSwimmingStrokeCount,
    );

    String uuid = '${await Health._channel.invokeMethod('writeWorkoutDataUUID', args)}';

    debugPrint("Added workout data point: $uuid");

    return uuid;
  }

  /// The arguments that both workout writes send, after the checks that [Health.writeWorkoutData] documents.
  Future<Map<String, dynamic>> _workoutArguments({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    required int? totalEnergyBurned,
    required HealthDataUnit totalEnergyBurnedUnit,
    required int? totalDistance,
    required HealthDataUnit totalDistanceUnit,
    required String? title,
    required WorkoutMetadata? metadata,
    required RecordingMethod recordingMethod,
    required String? clientRecordId,
    required double? clientRecordVersion,
    required Duration? startZoneOffset,
    required Duration? endZoneOffset,
    required SwimmingDetails? swimming,
    required int? totalSwimmingStrokeCount,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }
    _checkWorkoutActivityType(activityType);
    // Android would write the workout without a client record id that has no version, and HealthKit raises
    // an exception (crashing the app) for a sync identifier without its version, or a version without one.
    if ((clientRecordId == null) != (clientRecordVersion == null)) {
      throw ArgumentError("clientRecordId and clientRecordVersion must be given together");
    }
    if ((metadata?.syncIdentifier == null) != (metadata?.syncVersion == null)) {
      throw ArgumentError("WorkoutMetadata.syncIdentifier and syncVersion must be given together");
    }
    for (final offset in [startZoneOffset, endZoneOffset]) {
      if (offset != null && offset.abs() > const Duration(hours: 18)) {
        throw ArgumentError.value(offset, 'zone offset', 'must be at most 18 hours');
      }
    }
    final swimmingArguments = _swimmingArguments(activityType, start, end, swimming, totalSwimmingStrokeCount);
    return {
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
      if (clientRecordId != null) 'clientRecordId': clientRecordId,
      if (clientRecordVersion != null) 'clientRecordVersion': clientRecordVersion,
      if (startZoneOffset != null) 'startZoneOffsetSeconds': startZoneOffset.inSeconds,
      if (endZoneOffset != null) 'endZoneOffsetSeconds': endZoneOffset.inSeconds,
      ...swimmingArguments,
    };
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
