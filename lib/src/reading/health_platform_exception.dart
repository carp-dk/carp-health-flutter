part of '../../health.dart';

/// A [HealthException] for an error that Health Connect or HealthKit reported.
///
/// It is also a [PlatformException], which is what these errors were on iOS
/// before version 14.0.0, so existing `on PlatformException` and
/// `on HealthException` handlers keep working.
class HealthPlatformException extends PlatformException implements HealthException {
  /// Wrap [error], reported while reading [dataType].
  HealthPlatformException(this.dataType, PlatformException error)
    : cause = error.message ?? error.code,
      errorCode = HealthErrorCode.fromPlatformCode(error.code),
      super(code: error.code, message: error.message, details: error.details, stacktrace: error.stacktrace);

  @override
  dynamic dataType;

  @override
  String cause;

  @override
  final HealthErrorCode errorCode;

  @override
  String? get platformCode => code;

  @override
  bool get isRetryable => errorCode.isRetryable;

  @override
  String toString() => "Error requesting health data type '$dataType' - cause: $cause ($code)";
}
