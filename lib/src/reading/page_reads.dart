part of '../../health.dart';

/// The pages of one data type: read from the platform, or computed for BMI on
/// Android.
mixin _HealthPageReads on _HealthReadSupport {
  /// Reads [type] one native page at a time, as described for
  /// [Health.getHealthDataPages]. [newestFirst] selects HealthKit's order from
  /// before 14.0.0 (newest end date first) for [Health.getHealthDataFromTypes];
  /// Health Connect ignores it. A [limit] is sent for [_readNewest]: Health
  /// Connect then pages newest first by record start time, and the first page
  /// holds at most [limit] records. Once [cancellation] is set, no further
  /// platform call is made.
  Stream<HealthDataPage> _readPages(
    HealthDataType type,
    DateTime startTime,
    DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter,
    HealthDataUnit? unit, {
    required String deviceId,
    required int pageSize,
    required HealthIsolateMode mode,
    required bool newestFirst,
    int? limit,
    _ReadCancellation? cancellation,
  }) async* {
    final request = _ParseRequest(type, unit?.name ?? dataTypeToUnit[type]?.name, deviceId);
    // The arguments of the native getData method before 14.0.0, whose iOS side also read 'limit'.
    final legacyArgs = <String, dynamic>{
      'dataTypeKey': type.name,
      'dataUnitKey': request.unitName,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethodsToFilter': recordingMethodsToFilter.map((e) => e.toInt()).toList(),
      'limit': ?limit,
    };
    String? token;
    var first = true;
    while (true) {
      cancellation?.throwIfCancelled();
      _Page page;
      try {
        page = await _invokeAndParse(
          'getDataPage',
          {...legacyArgs, 'pageSize': pageSize, 'pageToken': token, 'newestFirst': newestFirst},
          _parsePage,
          request,
          mode,
        );
      } on MissingPluginException {
        if (!first) rethrow;
        page = _Page.none;
      }

      final points = page.points;
      if (points == null) {
        if (!first) {
          throw HealthException(type, 'getDataPage returned no page', errorCode: HealthErrorCode.unknown);
        }
        // A native side without getDataPage, or a test that mocks only getData:
        // read everything in one getData call, as before 14.0.0.
        cancellation?.throwIfCancelled();
        final all = await _invokeAndParse('getData', legacyArgs, _parseList, request, mode);
        yield HealthDataPage(type: type, points: all, isLastPageForType: true);
        return;
      }
      if (page.isComplete) {
        yield HealthDataPage(type: type, points: points, isLastPageForType: true);
        return;
      }

      final next = page.nextPageToken;
      if (next is! String?) {
        throw HealthException(type, 'getDataPage returned an invalid page token', errorCode: HealthErrorCode.unknown);
      }
      // A platform that stops advancing must not keep the read going forever.
      if (next != null && next == token) {
        throw HealthException(
          type,
          'The platform returned the same page token twice',
          errorCode: HealthErrorCode.unknown,
        );
      }
      final isLast = next == null;
      if (points.isNotEmpty || isLast) {
        yield HealthDataPage(
          type: type,
          points: points,
          isLastPageForType: isLast,
          readPermissionDenied: page.permissionDenied,
        );
      }
      if (isLast) return;
      token = next;
      first = false;
    }
  }

  /// The newest [limit] points of [type] as its one and last page, for
  /// [Health.getHealthDataFromTypes]: pages of at most [limit] points are read
  /// newest first until [limit] points are in. A page can hold more (the
  /// samples of a series record on Android, samples that end at the same time
  /// on iOS), so the points are sorted by end time, newest first, and cut to
  /// [limit]. Once [cancellation] is set, no further platform call is made.
  Future<HealthDataPage> _readNewest(
    HealthDataType type,
    DateTime startTime,
    DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter,
    HealthDataUnit? unit, {
    required String deviceId,
    required int pageSize,
    required HealthIsolateMode mode,
    required int limit,
    _ReadCancellation? cancellation,
  }) async {
    final points = <HealthDataPoint>[];
    var readPermissionDenied = false;
    final pages = _readPages(
      type,
      startTime,
      endTime,
      recordingMethodsToFilter,
      unit,
      deviceId: deviceId,
      pageSize: limit < pageSize ? limit : pageSize,
      mode: mode,
      newestFirst: true,
      limit: limit,
      cancellation: cancellation,
    );
    await for (final page in pages) {
      points.addAll(page.points);
      readPermissionDenied |= page.readPermissionDenied;
      if (points.length >= limit) break;
    }
    return HealthDataPage(
      type: type,
      points: _newest(points, limit),
      isLastPageForType: true,
      readPermissionDenied: readPermissionDenied,
    );
  }

  /// Calculate the BMI using the last observed height and weight values, as
  /// the one and last page of [HealthDataType.BODY_MASS_INDEX]. With a
  /// [limit], only the latest height and the newest [limit] weights are read.
  /// Once [cancellation] is set, no further height or weight page is read.
  Future<HealthDataPage> _computeAndroidBMI(
    DateTime startTime,
    DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter, {
    required String deviceId,
    required int pageSize,
    required HealthIsolateMode mode,
    int? limit,
    _ReadCancellation? cancellation,
  }) async {
    const dataType = HealthDataType.BODY_MASS_INDEX;
    var readPermissionDenied = false;
    Future<List<HealthDataPoint>> readAll(HealthDataType type, int? limit) async {
      if (limit != null) {
        final page = await _readNewest(
          type,
          startTime,
          endTime,
          recordingMethodsToFilter,
          null,
          deviceId: deviceId,
          pageSize: pageSize,
          mode: mode,
          limit: limit,
          cancellation: cancellation,
        );
        readPermissionDenied |= page.readPermissionDenied;
        return page.points;
      }
      final points = <HealthDataPoint>[];
      final pages = _readPages(
        type,
        startTime,
        endTime,
        recordingMethodsToFilter,
        null,
        deviceId: deviceId,
        pageSize: pageSize,
        mode: mode,
        newestFirst: false,
        cancellation: cancellation,
      );
      await for (final page in pages) {
        points.addAll(page.points);
        readPermissionDenied |= page.readPermissionDenied;
      }
      return points;
    }

    final heights = await readAll(HealthDataType.HEIGHT, limit == null ? null : 1);
    if (heights.isEmpty) {
      return HealthDataPage(
        type: dataType,
        points: [],
        isLastPageForType: true,
        readPermissionDenied: readPermissionDenied,
      );
    }
    final weights = await readAll(HealthDataType.WEIGHT, limit);

    // The latest height; of heights measured at the same time, the last one read.
    final height = heights.reduce((latest, next) => next.dateFrom.isBefore(latest.dateFrom) ? latest : next);
    final h = (height.value as NumericHealthValue).numericValue.toDouble();
    final unit = dataTypeToUnit[dataType]!;

    final bmiHealthPoints = <HealthDataPoint>{
      for (final weight in weights)
        HealthDataPoint(
          uuid: '',
          value: NumericHealthValue(
            numericValue: (weight.value as NumericHealthValue).numericValue.toDouble() / (h * h),
          ),
          type: dataType,
          unit: unit,
          dateFrom: weight.dateFrom,
          dateTo: weight.dateTo,
          sourcePlatform: platformType,
          sourceDeviceId: deviceId,
          sourceId: '',
          sourceName: '',
          recordingMethod: RecordingMethod.unknown,
        ),
    };
    return HealthDataPage(
      type: dataType,
      points: bmiHealthPoints.toList(),
      isLastPageForType: true,
      readPermissionDenied: readPermissionDenied,
    );
  }
}

/// The [limit] points of [points] that end last, newest first. Points that end
/// at the same time keep their order.
List<HealthDataPoint> _newest(List<HealthDataPoint> points, int limit) {
  final byEnd = points.indexed.toList()
    ..sort((a, b) {
      final order = b.$2.dateTo.compareTo(a.$2.dateTo);
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
  return [for (final (_, point) in byEnd.take(limit)) point];
}
