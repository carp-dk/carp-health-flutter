part of '../health.dart';

/// Custom Exception for the plugin. Used when a Health Data Type is requested,
/// but not available on the current platform.
class HealthException implements Exception {
  /// Data Type that was requested.
  dynamic dataType;

  /// Cause of the exception.
  String cause;

  HealthException(this.dataType, this.cause);

  @override
  String toString() => "Error requesting health data type '$dataType' - cause: $cause";
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

/// The status returned by [Health.getRequestStatusForAuthorization].
///
/// Mirrors Apple's
/// [`HKAuthorizationRequestStatus`](https://developer.apple.com/documentation/healthkit/hkauthorizationrequeststatus).
///
/// This indicates whether the authorization sheet would still be shown for the
/// requested types — it does **not** reveal whether *read* access was actually
/// granted, which HealthKit never exposes to apps.
enum HealthAuthorizationRequestStatus {
  /// It is unknown whether the app should request authorization (e.g. an error
  /// occurred while determining the status).
  unknown,

  /// The app should request authorization: at least one of the requested types
  /// has not been presented to the user yet.
  shouldRequest,

  /// Requesting authorization is unnecessary: the user has already been
  /// presented with the authorization sheet for all requested types.
  unnecessary;

  /// Maps the native string value (from the platform channel) to an enum value.
  static HealthAuthorizationRequestStatus? fromString(String? value) {
    return switch (value) {
      'shouldRequest' => HealthAuthorizationRequestStatus.shouldRequest,
      'unnecessary' => HealthAuthorizationRequestStatus.unnecessary,
      'unknown' => HealthAuthorizationRequestStatus.unknown,
      _ => null,
    };
  }
}
