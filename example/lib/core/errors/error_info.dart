/// Turns anything a plugin call can throw into text the UI can show (see `ErrorCard`).
///
/// The health plugin reports failures in several ways (README, "Error handling"):
/// a `HealthPlatformException` when Health Connect or HealthKit reports an error, a
/// `HealthException` for a type the platform or device does not have, an `UnsupportedError` when
/// Health Connect is missing, `ArgumentError`s for invalid arguments and plain `PlatformException`s
/// from writes. [ErrorInfo.from] covers each of them.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:health/health.dart';

/// A displayable description of an error: a short [title], the [message] the platform or plugin
/// gave, and what the user can do about it ([hint]).
class ErrorInfo {
  /// Creates an error description. Use [ErrorInfo.from] to describe a caught error.
  const ErrorInfo({
    required this.title,
    required this.message,
    this.code,
    this.platformCode,
    this.isRetryable = false,
    this.isPermission = false,
    this.hint,
  });

  /// Describes [error], whatever its type. `HealthPlatformException` is checked as a
  /// `HealthException` before the `PlatformException` it also is, as the README advises.
  factory ErrorInfo.from(Object error) => switch (error) {
    HealthException() => ErrorInfo._fromHealthException(error),
    MissingPluginException() => ErrorInfo(
      title: 'Plugin not available',
      message: error.message ?? 'The health plugin has no implementation on this platform.',
      hint: 'Run the example on an Android or iOS device.',
    ),
    PlatformException() => ErrorInfo._fromPlatformException(error),
    RangeError() => ErrorInfo(
      title: 'Value out of range',
      message: _messageOf(error.message, error),
      hint: 'Pick a value inside the allowed range.',
    ),
    ArgumentError() => ErrorInfo(
      title: 'Invalid argument',
      message: _messageOf(error.message, error),
      hint: 'The plugin checks arguments before it calls the platform: adjust the input and retry.',
    ),
    UnsupportedError() => ErrorInfo(
      title: 'Not available here',
      message: error.message ?? 'This operation is not supported.',
      // Thrown when Health Connect is missing, and by platform-only methods such as writeAudiogram.
      hint: 'This call is not available on this platform. On Android, check the Health Connect status in Setup.',
    ),
    StateError() => ErrorInfo(title: 'Invalid state', message: error.message),
    TimeoutException() => ErrorInfo(
      title: 'Timed out',
      message: error.message ?? 'The call did not finish in time.',
      isRetryable: true,
      hint: 'Try again.',
    ),
    FormatException() => ErrorInfo(title: 'Unexpected data', message: error.message),
    _ => ErrorInfo(title: 'Something went wrong', message: error.toString()),
  };

  /// A [HealthException] or [HealthPlatformException]: the plugin's error code says what happened.
  factory ErrorInfo._fromHealthException(HealthException error) {
    final code = error.errorCode;
    return ErrorInfo(
      title: _titles[code] ?? _titles[HealthErrorCode.unknown]!,
      message: error.cause,
      code: code.name,
      platformCode: error.platformCode,
      isRetryable: error.isRetryable,
      isPermission: code == HealthErrorCode.permissionDenied,
      hint: _hints[code],
    );
  }

  /// A plain [PlatformException], such as the INVALID_ARGUMENT a write throws on iOS. Its code is
  /// one of the plugin's native codes, so [HealthErrorCode.fromPlatformCode] classifies it.
  factory ErrorInfo._fromPlatformException(PlatformException error) {
    final code = HealthErrorCode.fromPlatformCode(error.code);
    final known = code != HealthErrorCode.unknown;
    return ErrorInfo(
      title: known ? _titles[code]! : 'Platform error',
      message: error.message ?? error.code,
      code: known ? code.name : null,
      platformCode: error.code,
      isRetryable: code.isRetryable,
      isPermission: code == HealthErrorCode.permissionDenied,
      hint: _hints[code],
    );
  }

  /// A short headline, such as "Permission needed".
  final String title;

  /// What went wrong, in the words of the plugin or platform.
  final String message;

  /// The [HealthErrorCode] name, such as `rateLimitExceeded`, when the error has one.
  final String? code;

  /// The native code Health Connect or HealthKit reported, such as `RATE_LIMIT_EXCEEDED`.
  final String? platformCode;

  /// Whether the same call may succeed later ([HealthErrorCode.isRetryable]). The plugin never
  /// retries on its own, so the UI offers a retry button.
  final bool isRetryable;

  /// Whether a missing permission caused the error, so the UI can link to the permission setup.
  final bool isPermission;

  /// What the user can do about it, when there is advice to give.
  final String? hint;

  /// A headline for each [HealthErrorCode].
  static const Map<HealthErrorCode, String> _titles = {
    HealthErrorCode.rateLimitExceeded: 'Rate limit reached',
    HealthErrorCode.permissionDenied: 'Permission needed',
    HealthErrorCode.invalidArgument: 'Invalid request',
    HealthErrorCode.notSupported: 'Not supported on this device',
    HealthErrorCode.unavailable: 'Health service unavailable',
    HealthErrorCode.deviceLocked: 'Device locked',
    HealthErrorCode.dataTooLarge: 'Too much data',
    HealthErrorCode.unknown: 'Health error',
  };

  /// Advice for the codes that have some (README, "Error handling" and "Health Connect limits").
  static const Map<HealthErrorCode, String> _hints = {
    HealthErrorCode.rateLimitExceeded:
        'Health Connect limits how often each app may call it. The quota refills over about '
        '15 minutes: try again later.',
    HealthErrorCode.permissionDenied: 'Grant access to this data type in Setup, then try again.',
    HealthErrorCode.invalidArgument: 'Check the values, units and time range of the request.',
    HealthErrorCode.notSupported: 'This platform, OS version or Health Connect version does not have this type.',
    HealthErrorCode.unavailable: 'Health Connect is busy or unreachable, for example while it syncs: retry shortly.',
    HealthErrorCode.deviceLocked: 'HealthKit protects health data while the device is locked: unlock it and retry.',
    HealthErrorCode.dataTooLarge: 'Read a shorter time range or lower the page size in Setup.',
  };

  /// The message of an [ArgumentError] or [RangeError], which may be any object or null.
  static String _messageOf(Object? message, Error error) => message == null ? error.toString() : message.toString();

  @override
  String toString() => code == null ? '$title: $message' : '$title ($code): $message';
}
