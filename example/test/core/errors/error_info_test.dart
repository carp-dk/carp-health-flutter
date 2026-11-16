import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/errors/error_info.dart';

void main() {
  test('HealthPlatformException uses its error code, not the PlatformException branch', () {
    final error = HealthPlatformException(
      HealthDataType.STEPS,
      PlatformException(code: 'RATE_LIMIT_EXCEEDED', message: 'quota used up'),
    );
    final info = ErrorInfo.from(error);
    expect(info.title, 'Rate limit reached');
    expect(info.message, 'quota used up');
    expect(info.code, 'rateLimitExceeded');
    expect(info.platformCode, 'RATE_LIMIT_EXCEEDED');
    expect(info.isRetryable, isTrue);
    expect(info.isPermission, isFalse);
    expect(info.hint, isNotNull);
  });

  test('permissionDenied is a permission error', () {
    final info = ErrorInfo.from(
      HealthPlatformException(HealthDataType.HEART_RATE, PlatformException(code: 'PERMISSION_DENIED')),
    );
    expect(info.isPermission, isTrue);
    expect(info.isRetryable, isFalse);
    expect(info.message, 'PERMISSION_DENIED');
  });

  test('HealthException from the plugin itself has no platform code', () {
    final info = ErrorInfo.from(
      HealthException(HealthDataType.SKIN_TEMPERATURE, 'Not available', errorCode: HealthErrorCode.notSupported),
    );
    expect(info.title, 'Not supported on this device');
    expect(info.code, 'notSupported');
    expect(info.platformCode, isNull);
  });

  test('a plain PlatformException is classified by its native code', () {
    final known = ErrorInfo.from(PlatformException(code: 'INVALID_ARGUMENT', message: 'bad unit'));
    expect(known.title, 'Invalid request');
    expect(known.code, 'invalidArgument');
    expect(known.platformCode, 'INVALID_ARGUMENT');

    final unknown = ErrorInfo.from(PlatformException(code: 'WRITE_ERROR'));
    expect(unknown.title, 'Platform error');
    expect(unknown.code, isNull);
    expect(unknown.message, 'WRITE_ERROR');
  });

  test('MissingPluginException explains where the plugin runs', () {
    expect(ErrorInfo.from(MissingPluginException()).title, 'Plugin not available');
  });

  test('Dart errors get their own titles', () {
    expect(ErrorInfo.from(ArgumentError('startTime must be earlier')).message, 'startTime must be earlier');
    expect(ErrorInfo.from(RangeError.range(0, 1, 50000)).title, 'Value out of range');
    expect(ErrorInfo.from(UnsupportedError('Health Connect missing')).message, 'Health Connect missing');
    expect(ErrorInfo.from(StateError('closed')).title, 'Invalid state');
    expect(ErrorInfo.from(TimeoutException('slow')).isRetryable, isTrue);
    expect(ErrorInfo.from(const FormatException('json')).title, 'Unexpected data');
  });

  test('anything else is described by its toString', () {
    final info = ErrorInfo.from(Exception('odd'));
    expect(info.title, 'Something went wrong');
    expect(info.message, 'Exception: odd');
    expect(info.toString(), 'Something went wrong: Exception: odd');
  });
}
