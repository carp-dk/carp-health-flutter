import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

/// Every code the native side reports, the codes used before 14.0.0, and a
/// code this version does not know yet, with their [HealthErrorCode] and
/// whether that is retryable.
const platformErrorCodes = <String, (HealthErrorCode, bool)>{
  'RATE_LIMIT_EXCEEDED': (HealthErrorCode.rateLimitExceeded, true),
  'PERMISSION_DENIED': (HealthErrorCode.permissionDenied, false),
  'INVALID_ARGUMENT': (HealthErrorCode.invalidArgument, false),
  'NOT_SUPPORTED': (HealthErrorCode.notSupported, false),
  'UNAVAILABLE': (HealthErrorCode.unavailable, true),
  'DEVICE_LOCKED': (HealthErrorCode.deviceLocked, true),
  'DATA_TOO_LARGE': (HealthErrorCode.dataTooLarge, false),
  'HEALTH_ERROR': (HealthErrorCode.unknown, false),
  'PERMISSION_ERROR': (HealthErrorCode.permissionDenied, false),
  'ARGUMENT_ERROR': (HealthErrorCode.invalidArgument, false),
  'INVALID_TYPE': (HealthErrorCode.invalidArgument, false),
  'UNSUPPORTED_FEATURE': (HealthErrorCode.notSupported, false),
  'STEPS_ERROR': (HealthErrorCode.unknown, false),
  'STATISTICS_ERROR': (HealthErrorCode.unknown, false),
  'error': (HealthErrorCode.unknown, false),
  'SOMETHING_NEW': (HealthErrorCode.unknown, false),
};

/// A [HealthPlatformException] for [type] with [code].
Matcher platformError(String code, {Object? type = HealthDataType.HEART_RATE, HealthErrorCode? errorCode}) => allOf(
  isA<PlatformException>().having((e) => e.code, 'code', code),
  isA<HealthException>()
      .having((e) => e.errorCode, 'errorCode', errorCode ?? platformErrorCodes[code]!.$1)
      .having((e) => e.platformCode, 'platformCode', code)
      .having((e) => e.dataType, 'dataType', type),
  isA<HealthPlatformException>(),
);
