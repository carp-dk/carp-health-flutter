part of '../health.dart';

/// Custom Exception for the plugin. Used when a Health Data Type is requested,
/// but not available on the current platform, and when Health Connect or
/// HealthKit reports an error while reading data. Errors reported by the
/// platform are [HealthPlatformException]s; [errorCode] says what went wrong.
class HealthException implements Exception {
  /// Data Type that was requested.
  dynamic dataType;

  /// Cause of the exception.
  String cause;

  /// What went wrong.
  final HealthErrorCode errorCode;

  /// The error code reported by Health Connect or HealthKit, for example
  /// `RATE_LIMIT_EXCEEDED`, or null if the plugin raised the exception itself.
  final String? platformCode;

  /// Extra information from the platform: on Android a map with the native
  /// `exception` class name and the `healthConnectErrorCode` (Android 14 and
  /// later, otherwise null), on iOS a map with the error `domain` and its
  /// `nativeCode`.
  final Object? details;

  /// Whether the same call may succeed if it is made again later. See
  /// [HealthErrorCode.isRetryable]. The plugin never retries on its own.
  bool get isRetryable => errorCode.isRetryable;

  HealthException(
    this.dataType,
    this.cause, {
    this.errorCode = HealthErrorCode.unknown,
    this.platformCode,
    this.details,
  });

  @override
  String toString() =>
      "Error requesting health data type '$dataType' - cause: $cause"
      "${platformCode == null ? '' : ' ($platformCode)'}";
}

/// What went wrong. See [HealthException.errorCode].
///
/// Values may be added in minor releases, so a `switch` over them needs a
/// default case.
enum HealthErrorCode {
  /// Health Connect rejected the call because the app used up its API quota.
  /// Retry later. The quotas depend on the Health Connect version and are much
  /// lower for reads in the background; see the README section
  /// "Health Connect limits".
  rateLimitExceeded('RATE_LIMIT_EXCEEDED'),

  /// The app does not have the permission the call needs, for example a read
  /// in the background without the Health Connect background read permission.
  /// A missing read permission for a data type is not an error: the type
  /// simply returns no data.
  permissionDenied('PERMISSION_DENIED'),

  /// The request was not valid, for example a unit that cannot express the
  /// data type.
  invalidArgument('INVALID_ARGUMENT'),

  /// The data type is not available on this platform or device.
  notSupported('NOT_SUPPORTED'),

  /// Health Connect cannot be reached or is busy right now, for example while
  /// it syncs data. Retry later. Health Connect missing altogether is reported
  /// as an [UnsupportedError] instead.
  unavailable('UNAVAILABLE'),

  /// iOS only. Health data is protected while the device is locked; retry once
  /// it is unlocked.
  deviceLocked('DEVICE_LOCKED'),

  /// The platform could not return this much data in one call. Read a shorter
  /// range or use a smaller [Health.pageSize].
  dataTooLarge('DATA_TOO_LARGE'),

  /// Any other error. See [HealthException.platformCode] and [HealthException.details].
  unknown('HEALTH_ERROR');

  const HealthErrorCode(this.platformCode);

  /// The code the native side of the plugin reports for this error.
  final String platformCode;

  /// Whether the same call may succeed if it is made again later: true for
  /// [rateLimitExceeded], [unavailable] and [deviceLocked].
  bool get isRetryable => this == rateLimitExceeded || this == unavailable || this == deviceLocked;

  /// The [HealthErrorCode] for a platform error [code], including the codes
  /// used before version 14.0.0; [unknown] if it is not recognized.
  static HealthErrorCode fromPlatformCode(String code) => switch (code) {
    'RATE_LIMIT_EXCEEDED' => rateLimitExceeded,
    'PERMISSION_DENIED' || 'PERMISSION_ERROR' => permissionDenied,
    'INVALID_ARGUMENT' || 'ARGUMENT_ERROR' || 'INVALID_TYPE' => invalidArgument,
    'NOT_SUPPORTED' || 'UNSUPPORTED_FEATURE' => notSupported,
    'UNAVAILABLE' => unavailable,
    'DEVICE_LOCKED' => deviceLocked,
    'DATA_TOO_LARGE' => dataTooLarge,
    // HEALTH_ERROR, STEPS_ERROR, STATISTICS_ERROR, ROUTE_ERROR, 'error', and codes added later.
    _ => unknown,
  };
}

/// Where the plugin decodes and parses the data that Health Connect or
/// HealthKit returns. The platform call itself is always made from the calling
/// isolate. See [Health.isolateMode].
enum HealthIsolateMode {
  /// The default. Replies of 64 KiB or more (a few hundred data points) are
  /// decoded, parsed and de-duplicated in a short-lived worker isolate, so the
  /// UI keeps running. Everything else is handled in the calling isolate:
  /// smaller replies, calls made from an isolate other than the root (UI)
  /// isolate, and calls made under `flutter test` (the `FLUTTER_TEST`
  /// environment variable is set and not `false`), so `testWidgets` never hangs.
  auto,

  /// Always decode and parse in a short-lived worker isolate, also under
  /// `flutter test`, where `testWidgets` then needs `tester.runAsync`.
  worker,

  /// Never start an isolate: decode and parse in the calling isolate. Use this
  /// in widget tests, or when you already call the plugin from your own isolate.
  inline,
}

/// The status of Google Health Connect.
///
/// **NOTE** - The enum order is arbitrary. If you need the native value,
/// use [nativeValue] and not the index.
///
/// Reference:
/// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#constants_1
enum HealthConnectSdkStatus {
  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#SDK_UNAVAILABLE()
  sdkUnavailable(1),

  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED()
  sdkUnavailableProviderUpdateRequired(2),

  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#SDK_AVAILABLE()
  sdkAvailable(3);

  const HealthConnectSdkStatus(this.nativeValue);

  /// The native value that matches the value in the Android SDK.
  final int nativeValue;

  factory HealthConnectSdkStatus.fromNativeValue(int value) {
    return HealthConnectSdkStatus.values.firstWhere(
      (e) => e.nativeValue == value,
      orElse: () => HealthConnectSdkStatus.sdkUnavailable,
    );
  }
}
