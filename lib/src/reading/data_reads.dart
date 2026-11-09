part of '../../health.dart';

/// The reads of [Health] that return data points: one by its UUID, or all in a
/// range at once or page by page.
mixin _HealthDataReads on _HealthPageReads {
  /// Implementation of [Health.getHealthDataByUUID].
  Future<HealthDataPoint?> getHealthDataByUUID({required String uuid, required HealthDataType type}) async {
    if (uuid.isEmpty) {
      throw HealthException(type, 'UUID is empty!', errorCode: HealthErrorCode.invalidArgument);
    }

    final mode = isolateMode;
    await _checkIfHealthConnectAvailableOnAndroid();
    await _checkTypesAvailable([type]);
    final deviceId = await _resolveDeviceId();

    // A record can be large, for example a long workout route, so its reply is
    // parsed like the other reads: in a worker isolate if [isolateMode] says so.
    final request = _ParseRequest(type, dataTypeToUnit[type]!.name, deviceId);
    final result = await _invokeAndParse(
      'getDataByUUID',
      <String, dynamic>{'dataTypeKey': type.name, 'dataUnitKey': request.unitName, 'uuid': uuid},
      _parseByUUID,
      request,
      mode,
    );

    debugPrint('data by UUID: ${result?.toString()}');

    return result;
  }

  /// Implementation of [Health.getHealthDataFromTypes].
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    final mode = isolateMode;
    final size = pageSize;
    _checkPreferredUnits(types, preferredUnits);
    final read = await _prepareRead(types);

    final dataPoints = <HealthDataPoint>[];
    for (final type in read.types) {
      // If BodyMassIndex is requested on Android, calculate this manually
      if (type == HealthDataType.BODY_MASS_INDEX && Platform.isAndroid) {
        final page = await _computeAndroidBMI(
          startTime,
          endTime,
          recordingMethodsToFilter,
          deviceId: read.deviceId,
          pageSize: size,
          mode: mode,
        );
        dataPoints.addAll(page.points);
        continue;
      }
      // HealthKit keeps its order from before 14.0.0 here: newest end date first.
      final pages = _readPages(
        type,
        startTime,
        endTime,
        recordingMethodsToFilter,
        preferredUnits?[type],
        deviceId: read.deviceId,
        pageSize: size,
        mode: mode,
        newestFirst: true,
      );
      await for (final page in pages) {
        dataPoints.addAll(page.points);
      }
    }
    return dataPoints;
  }

  /// Implementation of [Health.getHealthDataPages].
  Stream<HealthDataPage> getHealthDataPages({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? pageSize,
  }) => _cancellableRead((cancellation) async* {
    final size = pageSize ?? this.pageSize;
    RangeError.checkValueInInterval(size, 1, Health.maxPageSize, 'pageSize');
    final mode = isolateMode;
    _checkPreferredUnits(types, preferredUnits);
    final read = await _prepareRead(types, cancellation);

    for (final type in read.types) {
      // If BodyMassIndex is requested on Android, calculate this manually
      if (type == HealthDataType.BODY_MASS_INDEX && Platform.isAndroid) {
        yield await _computeAndroidBMI(
          startTime,
          endTime,
          recordingMethodsToFilter,
          deviceId: read.deviceId,
          pageSize: size,
          mode: mode,
          cancellation: cancellation,
        );
        continue;
      }
      final pages = _readPages(
        type,
        startTime,
        endTime,
        recordingMethodsToFilter,
        preferredUnits?[type],
        deviceId: read.deviceId,
        pageSize: size,
        mode: mode,
        newestFirst: false,
        cancellation: cancellation,
      );
      // Not `yield*`: after an error it would go on with the next type.
      await for (final page in pages) {
        yield page;
      }
    }
  });

  /// Implementation of [Health.removeDuplicates].
  List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points) => LinkedHashSet.of(points).toList();
}
