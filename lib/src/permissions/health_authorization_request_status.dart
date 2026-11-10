part of '../../health.dart';

/// Whether [Health.requestAuthorization] would show the authorization sheet,
/// as [Health.getRequestStatusForAuthorization] reports it. Mirrors HealthKit's
/// [`HKAuthorizationRequestStatus`](https://developer.apple.com/documentation/healthkit/hkauthorizationrequeststatus).
///
/// It does not tell whether read access was granted, which HealthKit does not
/// disclose to apps.
enum HealthAuthorizationRequestStatus {
  /// HealthKit could not determine the status. HealthKit reports this together
  /// with an error, which [Health.getRequestStatusForAuthorization] throws as a
  /// [PlatformException] instead.
  unknown,

  /// Requesting authorization would show the sheet: the user has not been asked
  /// yet for at least one of the types and access rights.
  shouldRequest,

  /// Requesting authorization would not show the sheet: the user has already
  /// been asked for all of the types and access rights.
  unnecessary;

  /// The status for a value the native side replies, or null for null or a
  /// value this version does not know.
  static HealthAuthorizationRequestStatus? fromString(String? value) => switch (value) {
    'shouldRequest' => shouldRequest,
    'unnecessary' => unnecessary,
    'unknown' => unknown,
    _ => null,
  };
}
