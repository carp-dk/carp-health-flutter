part of '../../health.dart';

/// What a worker isolate needs to turn platform data into [HealthDataPoint]s.
/// It holds plain data only: a closure that captured a [Health] instance would
/// copy the whole instance (or fail, if it holds something unsendable).
class _ParseRequest {
  const _ParseRequest(this.dataType, this.unitName, this.deviceId);

  /// Null when the reply carries its own types, as changes do.
  final HealthDataType? dataType;
  final String? unitName;
  final String deviceId;
}

/// A parsed reply of the native `getDataPage` method.
class _Page {
  const _Page(this.points, {this.nextPageToken, this.isComplete = false, this.permissionDenied = false});

  /// A null reply, from a native side or a test mock without `getDataPage`.
  static const none = _Page(null);

  /// Null for [none].
  final List<HealthDataPoint>? points;

  /// Checked by the caller: it must be null or a String.
  final Object? nextPageToken;

  /// The reply was a List, which holds all the data at once.
  final bool isComplete;

  final bool permissionDenied;
}

_Page _parsePage(Object? reply, _ParseRequest request) {
  if (reply == null) return _Page.none;
  if (reply is List) return _Page(_parsePoints(reply, request), isComplete: true);
  final data = reply is Map ? reply['data'] ?? const <Object?>[] : null;
  if (reply is! Map || data is! List) {
    throw HealthException(request.dataType, 'getDataPage returned an invalid page', errorCode: HealthErrorCode.unknown);
  }
  return _Page(
    _parsePoints(data, request),
    nextPageToken: reply['nextPageToken'],
    permissionDenied: reply['permissionDenied'] == true,
  );
}

/// A list reply, as from the native `getData` or aggregate methods.
List<HealthDataPoint> _parseList(Object? reply, _ParseRequest request) =>
    reply is List ? _parsePoints(reply, request) : <HealthDataPoint>[];

/// A reply of the native `getIntervalData` method: a point per interval whose
/// value is the number the platform computed for it (a sum, an average or the
/// minutes sleep covers), a [NumericHealthValue] for every type. For sleep or
/// activity intensity it is not what a read's point of that type holds (the
/// time the point spans, or an intensity level).
List<HealthDataPoint> _parseIntervals(Object? reply, _ParseRequest request) => [
  if (reply is List)
    for (final interval in reply)
      HealthDataPoint.fromHealthDataPoint(
        request.dataType!,
        interval,
        request.unitName,
        sourceDeviceId: request.deviceId,
      )..value = NumericHealthValue.fromHealthDataPoint(interval),
];

/// A reply of the native `getDataByUUID` method: null if the record was not
/// found. Android replies with an empty map when the record has nothing of this
/// type, for example a sleep session without the requested stage.
HealthDataPoint? _parseByUUID(Object? reply, _ParseRequest request) => reply is Map && reply.isNotEmpty
    ? HealthDataPoint.fromHealthDataPoint(request.dataType!, reply, request.unitName, sourceDeviceId: request.deviceId)
    : null;

HealthChangesResponse? _parseChanges(Object? reply, _ParseRequest request) =>
    reply is Map ? HealthChangesResponse.fromMethodChannel(reply, sourceDeviceId: request.deviceId) : null;

/// Converts native maps to points, without duplicates and in their order. A
/// native record never spans two pages, so removing duplicates per page equals
/// removing them over the whole read.
List<HealthDataPoint> _parsePoints(List<dynamic> data, _ParseRequest request) => <HealthDataPoint>{
  for (final dataPoint in data)
    HealthDataPoint.fromHealthDataPoint(
      request.dataType!,
      dataPoint,
      request.unitName,
      sourceDeviceId: request.deviceId,
    ),
}.toList();
