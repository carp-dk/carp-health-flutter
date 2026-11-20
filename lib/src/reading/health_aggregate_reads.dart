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
  ///  * for [HealthDataType.MINDFULNESS], the minutes of the interval covered
  ///    by mindfulness sessions: on Android those Health Connect computes
  ///    (`MINDFULNESS_DURATION_TOTAL`), on iOS those HealthKit's mindful
  ///    sessions cover, overlapping sessions counted once, as for sleep;
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
  ///    [HealthDataType.ACTIVITY_INTENSITY] and [HealthDataType.MINDFULNESS]
  ///    (minutes) do. Any other type returns no data points, even if it has
  ///    data;
  ///  * on iOS, the sleep types, [HealthDataType.MINDFULNESS] and the quantity
  ///    types do, except [HealthDataType.APPLE_MOVE_TIME],
  ///    [HealthDataType.APPLE_STAND_TIME],
  ///    [HealthDataType.ATRIAL_FIBRILLATION_BURDEN],
  ///    [HealthDataType.EXERCISE_TIME], [HealthDataType.INSULIN_DELIVERY],
  ///    [HealthDataType.PERIPHERAL_PERFUSION_INDEX],
  ///    [HealthDataType.RESPIRATORY_RATE], [HealthDataType.UNDERWATER_DEPTH],
  ///    [HealthDataType.WALKING_SPEED] and [HealthDataType.WATER_TEMPERATURE].
  ///    Any other type, such as a workout or a headache, throws a
  ///    [HealthPlatformException] with [HealthErrorCode.invalidArgument]
  ///    (platform code INVALID_TYPE). A type this iOS version does not have,
  ///    such as [HealthDataType.ROWING_SPEED] before iOS 18, throws one with
  ///    [HealthErrorCode.notSupported] (platform code NOT_SUPPORTED), as reads
  ///    of it do.
  ///
  /// On both platforms, the [HealthDataPoint.sourceName] of a data point names
  /// the apps whose data it holds, joined by ", " (Android package names, iOS
  /// bundle identifiers), and its [HealthDataPoint.sourceId] is empty. For
  /// sums and averages, these are the apps with data in that interval; on iOS
  /// they are sorted and can include devices. For the sleep types, and for
  /// [HealthDataType.MINDFULNESS] on iOS, they are the apps whose samples
  /// cover part of the interval, each once, in the order their samples start.
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
  /// A filter that cannot be applied prints a warning to the console.
  ///
  /// On Android, the sums of the activity types ([HealthDataType.STEPS],
  /// [HealthDataType.DISTANCE_DELTA], [HealthDataType.ACTIVE_ENERGY_BURNED],
  /// [HealthDataType.TOTAL_CALORIES_BURNED] and the
  /// [HealthDataType.ACTIVITY_INTENSITY] minutes) and, on recent Health
  /// Connect versions, the [HealthDataType.MINDFULNESS] minutes count only the
  /// apps in the user's Health Connect app priority list for the category,
  /// and where the data of several apps overlap, only the highest-priority
  /// app. An app joins that list when the user grants it a write permission
  /// of the category in Health Connect's permission screen
  /// ([Health.requestAuthorization]), not when it is granted with
  /// `adb shell pm grant`. Other intervals, such as heart rate averages and
  /// the sleep types, combine the data of every app.
  ///
  /// Throws a [HealthException] with [HealthErrorCode.notSupported] if a type
  /// is not available on this platform or device (before anything is read),
  /// and a [HealthPlatformException] if Health Connect or HealthKit reports an
  /// error. On Android, that is [HealthErrorCode.permissionDenied] for a type
  /// without its read permission, also with its write permission, as these
  /// reads cover the data of every app. HealthKit hides a denied read: the
  /// intervals then hold only the samples this app saved.
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    final mode = isolateMode;
    final read = await _prepareRead(types);
    _warnUnfilteredIntervals(platformType, read.types, recordingMethodsToFilter);
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
  /// On Android this is Health Connect's step aggregate, which counts only the
  /// apps in the user's app priority list (see
  /// [getHealthIntervalDataFromTypes]). With [includeManualEntry] false it
  /// instead adds up the step records of every app that start in the interval
  /// and are not manual entries, as Health Connect's aggregates cannot filter
  /// by recording method: it does not leave out apps outside the priority
  /// list, counts the overlapping data of several apps twice, and does not
  /// split records that cross the interval's bounds.
  ///
  /// Throws an [UnsupportedError] if Health Connect is not available, and a
  /// [HealthPlatformException] if Health Connect or HealthKit reports an
  /// error, for example [HealthErrorCode.rateLimitExceeded] when Health
  /// Connect's API quota is used up, or, on Android,
  /// [HealthErrorCode.permissionDenied] without the steps read permission,
  /// also with the write permission. HealthKit does not report a denied read
  /// permission: it counts only the steps this app saved (0 if none).
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
