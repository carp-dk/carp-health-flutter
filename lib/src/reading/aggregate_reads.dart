part of '../../health.dart';

/// The reads of [Health] that return aggregate health data and total step
/// counts.
mixin _HealthAggregateReads on _HealthReadSupport {
  /// Implementation of [Health.getHealthIntervalDataFromTypes].
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

  /// Implementation of [Health.getHealthAggregateDataFromTypes].
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

  /// Implementation of [Health.getTotalStepsInInterval].
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
