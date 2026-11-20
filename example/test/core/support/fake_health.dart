/// A [Health] whose availability checks answer from fields instead of platform channels, for
/// testing `PlatformCapabilities` and what is built on it.
library;

import 'package:health/health.dart';

/// The names of the checks [FakeHealth] answers, for [FakeHealth.features] and [FakeHealth.failing].
abstract final class FakeCheck {
  /// `getHealthConnectSdkStatus`.
  static const String sdkStatus = 'sdkStatus';

  /// `isHealthDataHistoryAvailable`.
  static const String historyAvailable = 'historyAvailable';

  /// `isHealthDataHistoryAuthorized`.
  static const String historyAuthorized = 'historyAuthorized';

  /// `isHealthDataInBackgroundAvailable`.
  static const String backgroundAvailable = 'backgroundAvailable';

  /// `isHealthDataInBackgroundAuthorized`.
  static const String backgroundAuthorized = 'backgroundAuthorized';

  /// `isSkinTemperatureAvailable`.
  static const String skinTemperature = 'skinTemperature';

  /// `isMindfulnessSessionAvailable`.
  static const String mindfulness = 'mindfulness';

  /// `isActivityIntensityAvailable`.
  static const String activityIntensity = 'activityIntensity';
}

/// A [Health] with scripted answers to the Health Connect status and feature checks.
class FakeHealth extends Health {
  /// Answers [sdkStatus] and the [features] (missing ones are false); the checks named in
  /// [failing] throw [error] instead.
  FakeHealth({
    this.sdkStatus = HealthConnectSdkStatus.sdkAvailable,
    Map<String, bool>? features,
    Set<String>? failing,
    this.error = const FormatException('check failed'),
  }) : features = features ?? {},
       failing = failing ?? {};

  /// What [getHealthConnectSdkStatus] answers.
  HealthConnectSdkStatus? sdkStatus;

  /// What each feature check answers, by [FakeCheck] name.
  final Map<String, bool> features;

  /// The [FakeCheck] names of the checks that throw [error].
  final Set<String> failing;

  /// What the failing checks throw.
  final Object error;

  /// How often each check was called, by [FakeCheck] name.
  final Map<String, int> calls = {};

  Future<T> _answer<T>(String check, T Function() answer) async {
    calls[check] = (calls[check] ?? 0) + 1;
    if (failing.contains(check)) throw error;
    return answer();
  }

  Future<bool> _feature(String check) => _answer(check, () => features[check] ?? false);

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() => _answer(FakeCheck.sdkStatus, () => sdkStatus);

  @override
  Future<bool> isHealthDataHistoryAvailable() => _feature(FakeCheck.historyAvailable);

  @override
  Future<bool> isHealthDataHistoryAuthorized() => _feature(FakeCheck.historyAuthorized);

  @override
  Future<bool> isHealthDataInBackgroundAvailable() => _feature(FakeCheck.backgroundAvailable);

  @override
  Future<bool> isHealthDataInBackgroundAuthorized() => _feature(FakeCheck.backgroundAuthorized);

  @override
  Future<bool> isSkinTemperatureAvailable() => _feature(FakeCheck.skinTemperature);

  @override
  Future<bool> isMindfulnessSessionAvailable() => _feature(FakeCheck.mindfulness);

  @override
  Future<bool> isActivityIntensityAvailable() => _feature(FakeCheck.activityIntensity);
}

/// Every Health Connect feature available, as on Android 16 and later.
Map<String, bool> allFeatures() => {
  FakeCheck.historyAvailable: true,
  FakeCheck.historyAuthorized: true,
  FakeCheck.backgroundAvailable: true,
  FakeCheck.backgroundAuthorized: true,
  FakeCheck.skinTemperature: true,
  FakeCheck.mindfulness: true,
  FakeCheck.activityIntensity: true,
};
