part of '../../health.dart';

/// Part of [Health]: the reads that return aggregate health data and total
/// step counts.
// ignore: library_private_types_in_public_api
mixin HealthAggregateReads on _HealthReadSupport {
  /// Fetch [types] aggregated over intervals of [interval] seconds from
  /// [startDate] to [endDate], one data point per type and interval.
  /// Intervals without data are left out on both platforms.
  ///
  /// The value of a data point is a [NumericHealthValue]:
  ///  * the sum for cumulative types (steps, energy, distance, water, ...);
  ///  * for sleep types, the minutes of the interval covered by that type's
  ///    data points: the points [Health.getHealthDataFromTypes] returns for
  ///    it, and points that began before [startDate] with their part after it
  ///    (on Android, of sessions that began up to 24 hours earlier). On
  ///    Android these come from sleep sessions and their stages:
  ///    [HealthDataType.SLEEP_IN_BED] is iOS-only, use
  ///    [HealthDataType.SLEEP_SESSION] there;
  ///  * for [HealthDataType.ACTIVITY_INTENSITY] (Android), the intensity
  ///    minutes Health Connect computes (`INTENSITY_MINUTES_TOTAL`);
  ///  * the average for any other type. For heart rate, that is the average
  ///    beats per minute: HealthKit weights the samples by the time they
  ///    cover, Health Connect takes the mean of the samples.
  ///
  /// Not every type has intervals:
  ///  * on Android, the sleep types, [HealthDataType.STEPS],
  ///    [HealthDataType.ACTIVE_ENERGY_BURNED],
  ///    [HealthDataType.TOTAL_CALORIES_BURNED], [HealthDataType.DISTANCE_DELTA]
  ///    and [HealthDataType.WATER] (sums), [HealthDataType.HEART_RATE],
  ///    [HealthDataType.WEIGHT], [HealthDataType.HEIGHT],
  ///    [HealthDataType.POWER], [HealthDataType.CYCLING_CADENCE] and
  ///    [HealthDataType.SKIN_TEMPERATURE] (averages), and
  ///    [HealthDataType.ACTIVITY_INTENSITY] do. Any other type returns no data
  ///    points, even if it has data;
  ///  * on iOS, the sleep types and the quantity types do, except
  ///    [HealthDataType.APPLE_MOVE_TIME], [HealthDataType.APPLE_STAND_TIME],
  ///    [HealthDataType.ATRIAL_FIBRILLATION_BURDEN],
  ///    [HealthDataType.EXERCISE_TIME], [HealthDataType.INSULIN_DELIVERY],
  ///    [HealthDataType.PERIPHERAL_PERFUSION_INDEX],
  ///    [HealthDataType.RESPIRATORY_RATE], [HealthDataType.UNDERWATER_DEPTH],
  ///    [HealthDataType.WALKING_SPEED] and [HealthDataType.WATER_TEMPERATURE].
  ///    Any other type, such as a workout, [HealthDataType.MINDFULNESS] or a
  ///    headache, throws a [HealthPlatformException] with
  ///    [HealthErrorCode.invalidArgument] (platform code INVALID_TYPE).
  ///
  /// Data of the recording methods in [recordingMethodsToFilter] is left out
  /// (by default none is), as far as the platform can filter it:
  ///  * on iOS, only [RecordingMethod.manual] is left out: HealthKit marks only
  ///    the samples the user entered (`HKWasUserEntered`), so the other
  ///    methods are ignored;
  ///  * on Android, only the sleep types are filtered: the intervals of every
  ///    other type are Health Connect aggregates, which cannot be filtered by
  ///    recording method, so they include data of every recording method.
  ///
  /// Throws a [HealthException] with [HealthErrorCode.notSupported] if a type
  /// is not available on this platform or device (before anything is read),
  /// and a [HealthPlatformException] if Health Connect or HealthKit reports an
  /// error.
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    final mode = isolateMode;
    final read = await _prepareRead(types);
    final dataPoints = <HealthDataPoint>[];

    for (final type in read.types) {
      final args = <String, dynamic>{
        'dataTypeKey': type.name,
        'dataUnitKey': dataTypeToUnit[type]!.name,
        'startTime': startDate.millisecondsSinceEpoch,
        'endTime': endDate.millisecondsSinceEpoch,
        'interval': interval,
        'recordingMethodsToFilter': recordingMethodsToFilter.map((e) => e.toInt()).toList(),
      };
      dataPoints.addAll(
        await _invokeAndParse('getIntervalData', args, _parseIntervals, _ParseRequest(type, null, read.deviceId), mode),
      );
    }
    return dataPoints;
  }

  /// Deprecated: use [getHealthIntervalDataFromTypes], which aggregates
  /// [types] over intervals on both platforms.
  ///
  /// Throws an [UnsupportedError] without calling the platform. This method
  /// has not worked on either platform since Google Fit was removed: iOS has
  /// no such read, and on Android only the interval reads of
  /// [getHealthIntervalDataFromTypes] remain, which take other arguments.
  @Deprecated(
    'Throws an UnsupportedError: it has not worked since Google Fit was removed. '
    'Use getHealthIntervalDataFromTypes instead.',
  )
  Future<List<HealthDataPoint>> getHealthAggregateDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startDate,
    required DateTime endDate,
    int activitySegmentDuration = 1,
    bool includeManualEntry = true,
  }) async {
    throw UnsupportedError(
      'getHealthAggregateDataFromTypes has not worked on either platform since Google Fit was removed: '
      'use getHealthIntervalDataFromTypes instead.',
    );
  }

  /// Get the total number of steps within a specific time period: 0 if there
  /// are no steps in it.
  ///
  /// Throws an [UnsupportedError] if Health Connect is not available, and a
  /// [HealthPlatformException] if Health Connect or HealthKit reports an
  /// error, for example [HealthErrorCode.rateLimitExceeded] when Health
  /// Connect's API quota is used up, or, on Android,
  /// [HealthErrorCode.permissionDenied] without the steps read permission.
  /// HealthKit does not report a denied read permission: it returns 0.
  Future<int> getTotalStepsInInterval(DateTime startTime, DateTime endTime, {bool includeManualEntry = true}) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    final args = <String, dynamic>{
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethodsToFilter': includeManualEntry ? <RecordingMethod>[] : [RecordingMethod.manual.toInt()],
    };
    return await _invoke<int>('getTotalStepsInInterval', args, dataType: HealthDataType.STEPS) ?? 0;
  }
}
