part of '../../health.dart';

/// Part of [Health]: the reads that return aggregate health data and total
/// step counts.
// ignore: library_private_types_in_public_api
mixin HealthAggregateReads on _HealthReadSupport {
  /// Fetch a list of health data points based on [types].
  /// You can also specify the [recordingMethodsToFilter] to filter the data points.
  /// If not specified, all data points will be included.
  ///
  /// Throws a [HealthPlatformException] if Health Connect or HealthKit reports an error.
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
        await _invokeAndParse('getIntervalData', args, _parseList, _ParseRequest(type, null, read.deviceId), mode),
      );
    }
    return dataPoints;
  }

  /// Fetch a list of health data points based on [types].
  ///
  /// Throws a [HealthPlatformException] if Health Connect or HealthKit reports an error.
  Future<List<HealthDataPoint>> getHealthAggregateDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startDate,
    required DateTime endDate,
    int activitySegmentDuration = 1,
    bool includeManualEntry = true,
  }) async {
    final mode = isolateMode;
    await _checkIfHealthConnectAvailableOnAndroid();
    await _checkTypesAvailable(types);
    final deviceId = await _resolveDeviceId();

    final args = <String, dynamic>{
      'dataTypeKeys': types.map((dataType) => dataType.name).toList(),
      'startTime': startDate.millisecondsSinceEpoch,
      'endTime': endDate.millisecondsSinceEpoch,
      'activitySegmentDuration': activitySegmentDuration,
      'includeManualEntry': includeManualEntry,
    };
    return _invokeAndParse(
      'getAggregateData',
      args,
      _parseList,
      _ParseRequest(HealthDataType.WORKOUT, null, deviceId),
      mode,
    );
  }

  /// Get the total number of steps within a specific time period.
  /// Returns null if not successful, for example when Health Connect's API
  /// quota is used up.
  Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime, {bool includeManualEntry = true}) async {
    final args = <String, dynamic>{
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethodsToFilter': includeManualEntry ? <RecordingMethod>[] : [RecordingMethod.manual.toInt()],
    };
    try {
      return await Health._channel.invokeMethod<int?>('getTotalStepsInInterval', args);
    } on PlatformException catch (e) {
      debugPrint('$runtimeType - Exception in getTotalStepsInInterval(): $e');
      return null;
    }
  }
}
