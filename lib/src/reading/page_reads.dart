part of '../../health.dart';

/// The pages of one data type: read from the platform, or computed for BMI on
/// Android.
mixin _HealthPageReads on _HealthReadSupport {
  /// Reads [type] one native page at a time, as described for
  /// [Health.getHealthDataPages]. [newestFirst] selects HealthKit's order from
  /// before 14.0.0 (newest end date first) for [Health.getHealthDataFromTypes];
  /// Health Connect ignores it. Once [cancellation] is set, no further platform
  /// call is made.
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
    _ReadCancellation? cancellation,
  }) async* {
    final request = _ParseRequest(type, unit?.name ?? dataTypeToUnit[type]?.name, deviceId);
    // The arguments of the native getData method before 14.0.0.
    final legacyArgs = <String, dynamic>{
      'dataTypeKey': type.name,
      'dataUnitKey': request.unitName,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethodsToFilter': recordingMethodsToFilter.map((e) => e.toInt()).toList(),
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

  /// Calculate the BMI using the last observed height and weight values, as
  /// the one and last page of [HealthDataType.BODY_MASS_INDEX]. Once
  /// [cancellation] is set, no further height or weight page is read.
  Future<HealthDataPage> _computeAndroidBMI(
    DateTime startTime,
    DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter, {
    required String deviceId,
    required int pageSize,
    required HealthIsolateMode mode,
    _ReadCancellation? cancellation,
  }) async {
    const dataType = HealthDataType.BODY_MASS_INDEX;
    var readPermissionDenied = false;
    Future<List<HealthDataPoint>> readAll(HealthDataType type) async {
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

    final heights = await readAll(HealthDataType.HEIGHT);
    if (heights.isEmpty) {
      return HealthDataPage(
        type: dataType,
        points: [],
        isLastPageForType: true,
        readPermissionDenied: readPermissionDenied,
      );
    }
    final weights = await readAll(HealthDataType.WEIGHT);

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
