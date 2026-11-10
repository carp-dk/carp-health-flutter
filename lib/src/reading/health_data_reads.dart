part of '../../health.dart';

/// Part of [Health]: the reads that return data points, one by its UUID, or
/// all in a range at once or page by page, and [removeDuplicates] for lists of
/// them.
// ignore: library_private_types_in_public_api
mixin HealthDataReads on _HealthPageReads {
  /// Fetch a `HealthDataPoint` by `uuid` and `type`. Returns `null` if no matching record.
  ///
  /// Parameters:
  ///  * [uuid] - UUID of your saved health data point (e.g. A91A2F10-3D7B-486A-B140-5ADCD3C9C6D0)
  ///  * [type] - Data type of your saved health data point (e.g. HealthDataType.WORKOUT)
  ///
  /// Assuming above data are coming from your database.
  ///
  /// Throws a [HealthPlatformException] if Health Connect or HealthKit reports
  /// an error other than the record not being found.
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

  /// Fetch a list of health data points based on [types].
  /// You can also specify the [recordingMethodsToFilter] to filter the data points.
  /// If not specified, all data points will be included.
  ///
  /// Types are read in the order of [types], each type once. Within a type,
  /// points are oldest first on Android (by the start time of their record:
  /// the stages of a sleep session come together) and newest first on iOS (by
  /// end time), without duplicates.
  ///
  /// Sleep data points are returned when they start at or after [startTime]
  /// and before [endTime], so reads of consecutive ranges return each of them
  /// once: a [HealthDataType.SLEEP_SESSION] (Android) when the session starts
  /// in the range, a stage such as [HealthDataType.SLEEP_DEEP] when the stage
  /// does, whichever session it is part of. On Android, this finds the stages
  /// of sessions that began up to 24 hours before [startTime], not those of
  /// sessions that began earlier.
  ///
  /// Data is read about [Health.pageSize] points per platform call and parsed
  /// as set by [Health.isolateMode], so neither the native side nor the UI has
  /// to handle the whole range at once. The returned list does hold all points:
  /// for large ranges, use [getHealthDataPages] and process the data page by
  /// page.
  ///
  /// Throws a [HealthException] with [HealthErrorCode.notSupported] if a type
  /// is not available on this platform or device (before anything is read),
  /// and a [HealthPlatformException] if Health Connect or HealthKit reports an
  /// error, for example [HealthErrorCode.rateLimitExceeded]. The call then
  /// fails as a whole, so do not record sync progress for any of [types].
  /// A missing read permission is not an error: that type simply returns no data.
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

  /// Read health data of [types] between [startTime] and [endTime] page by page.
  ///
  /// Use this instead of [getHealthDataFromTypes] for large ranges, for example
  /// a first sync of months of heart rate data. Each page holds about
  /// [pageSize] points (default [Health.pageSize]). The stream is lazy: nothing
  /// is read until it is listened to, and the next page is read only when the
  /// listener is ready for it (with `await for`, once the loop body has
  /// finished). Memory therefore stays bounded if you process each page and
  /// let it go. [Health.isolateMode] and [Health.pageSize] are read when the
  /// stream is listened to.
  ///
  /// Types are read one after another, in the order of [types], each type
  /// once. Within a type, points are oldest first: in the order of their
  /// records' start times on Android (the samples of a heart rate, speed,
  /// power, cycling cadence or skin temperature record come together, as do
  /// the stages of a sleep session), by end time on iOS. Each type ends with
  /// exactly one page whose
  /// [HealthDataPage.isLastPageForType] is true (empty if the type has no more
  /// data); other pages are never empty. This is a finite read of the data
  /// stored now, not a live stream of new data, and not a snapshot: data
  /// written while it runs may or may not be included.
  ///
  /// Sleep data points are returned when they start at or after [startTime]
  /// and before [endTime], so reads of consecutive ranges return each of them
  /// once: a [HealthDataType.SLEEP_SESSION] (Android) when the session starts
  /// in the range, a stage such as [HealthDataType.SLEEP_DEEP] when the stage
  /// does, whichever session it is part of. On Android, this finds the stages
  /// of sessions that began up to 24 hours before [startTime], not those of
  /// sessions that began earlier.
  ///
  /// An error ends the stream; pages already delivered stay valid. The error is
  /// a [RangeError] for an invalid [pageSize], a [HealthException] with
  /// [HealthErrorCode.notSupported] if a type is not available on this platform
  /// or device (before anything is read), or a [HealthPlatformException] if
  /// Health Connect or HealthKit reports an error. Cancelling the subscription
  /// stops the read: no platform call is made after the one in flight, whose
  /// page or error is dropped, and the future that `cancel` returns completes
  /// once that call has returned. A missing read permission is not an error:
  /// that type returns one empty page, with
  /// [HealthDataPage.readPermissionDenied] set on Android.
  ///
  /// On Android every page costs Health Connect calls, which count against its
  /// API quota. See the README section "Health Connect limits".
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

  /// Return a list of [HealthDataPoint] based on [points] with no duplicates.
  List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points) => LinkedHashSet.of(points).toList();
}
