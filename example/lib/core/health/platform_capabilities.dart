/// What the device's health platform offers: Health Connect's status and optional features on
/// Android, the iOS version on iOS, and from them which data types work here.
///
/// Demonstrates the plugin's availability checks: `getHealthConnectSdkStatus`,
/// `isHealthDataHistoryAvailable` / `isHealthDataHistoryAuthorized`,
/// `isHealthDataInBackgroundAvailable` / `isHealthDataInBackgroundAuthorized`,
/// `isSkinTemperatureAvailable`, `isMindfulnessSessionAvailable` and
/// `isActivityIntensityAvailable`.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'type_rules.dart';

/// The health platform of this device and what it supports. [refresh] asks the plugin; listeners
/// are notified when a refresh completes.
class PlatformCapabilities extends ChangeNotifier {
  /// Creates the capabilities of the device [health] runs on.
  ///
  /// [platform] and [iosMajorVersion] override what is detected from `dart:io`, so tests can
  /// pretend to run on either platform without platform channels.
  PlatformCapabilities(this.health, {HealthPlatformType? platform, int? iosMajorVersion})
    : platform = platform ?? _detectPlatform(),
      iosMajorVersion = iosMajorVersion ?? _detectIosMajorVersion();

  /// The plugin instance whose platform this describes.
  final Health health;

  /// The health platform of this device, or null where the plugin has none (desktop, web).
  final HealthPlatformType? platform;

  /// The major iOS version, such as 18, or null when unknown or not on iOS. Newer HealthKit
  /// types need a minimum version ([TypeRules.iosMinimumVersion]).
  final int? iosMajorVersion;

  HealthConnectSdkStatus? _sdkStatus;
  bool _historyAvailable = false;
  bool _historyAuthorized = false;
  bool _backgroundAvailable = false;
  bool _backgroundAuthorized = false;
  bool _skinTemperatureAvailable = false;
  bool _mindfulnessAvailable = false;
  bool _activityIntensityAvailable = false;
  bool _isLoaded = false;
  Object? _lastError;
  Future<void>? _refreshing;
  bool _disposed = false;

  /// Whether this is an Android device, where the plugin uses Health Connect.
  bool get isAndroid => platform == HealthPlatformType.googleHealthConnect;

  /// Whether this is an iOS device, where the plugin uses HealthKit.
  bool get isIOS => platform == HealthPlatformType.appleHealth;

  /// The name of the health platform: "Health Connect" or "Apple Health".
  String get platformName => switch (platform) {
    HealthPlatformType.googleHealthConnect => 'Health Connect',
    HealthPlatformType.appleHealth => 'Apple Health',
    null => 'No health platform',
  };

  /// Health Connect's status from `getHealthConnectSdkStatus`; null on iOS, before [refresh] and
  /// when the status could not be read.
  HealthConnectSdkStatus? get sdkStatus => _sdkStatus;

  /// Whether the plugin can be used: on Android when Health Connect is available
  /// (`HealthConnectSdkStatus.sdkAvailable`), and always on iOS, as the plugin's
  /// `isHealthConnectAvailable` answers.
  bool get healthConnectAvailable => isIOS || (isAndroid && _sdkStatus == HealthConnectSdkStatus.sdkAvailable);

  /// Whether Health Connect must be installed or updated first (Android 13 and lower), which
  /// `installHealthConnect` offers. From Android 14 on, Health Connect updates with the system.
  bool get needsHealthConnectInstall =>
      isAndroid && _sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;

  /// Whether reading data older than 30 days can be requested (`isHealthDataHistoryAvailable`).
  bool get historyAvailable => _historyAvailable;

  /// Whether reading data older than 30 days is granted (`isHealthDataHistoryAuthorized`; the
  /// plugin answers true on iOS, which has no such permission).
  bool get historyAuthorized => _historyAuthorized;

  /// Whether reading in the background can be requested (`isHealthDataInBackgroundAvailable`).
  bool get backgroundAvailable => _backgroundAvailable;

  /// Whether reading in the background is granted (`isHealthDataInBackgroundAuthorized`; the
  /// plugin answers true on iOS).
  bool get backgroundAuthorized => _backgroundAuthorized;

  /// Whether Health Connect has skin temperature (`isSkinTemperatureAvailable`; false on iOS).
  bool get skinTemperatureAvailable => _skinTemperatureAvailable;

  /// Whether mindfulness sessions exist (`isMindfulnessSessionAvailable`; true on iOS).
  bool get mindfulnessAvailable => _mindfulnessAvailable;

  /// Whether Health Connect has activity intensity (`isActivityIntensityAvailable`; false on iOS).
  bool get activityIntensityAvailable => _activityIntensityAvailable;

  /// Whether a [refresh] has completed.
  bool get isLoaded => _isLoaded;

  /// Whether a [refresh] is running.
  bool get isRefreshing => _refreshing != null;

  /// The first failure of the last [refresh], or null if everything could be checked.
  Object? get lastError => _lastError;

  /// Asks the plugin for the platform's status and features. Never throws: a failed check leaves
  /// its flag false and is kept as [lastError]. Calls made while a refresh runs share it.
  Future<void> refresh() => _refreshing ??= _load().whenComplete(() => _refreshing = null);

  /// Whether [type] can be read and written here: it is one of the platform's types
  /// (`dataTypeKeysAndroid` / `dataTypeKeysIOS`), this iOS version has it, and on Android the
  /// device's Health Connect has its feature. Otherwise the plugin throws
  /// `HealthErrorCode.notSupported` for it.
  bool supports(HealthDataType type) => unsupportedReason(type) == null;

  /// Why [type] is not supported here, or null if it is ([supports]).
  String? unsupportedReason(HealthDataType type) {
    final platform = this.platform;
    if (platform == null) return 'The health plugin supports Android and iOS only';
    if (!TypeRules.platformTypes(platform).contains(type)) return 'Not available in $platformName';
    switch (platform) {
      case HealthPlatformType.googleHealthConnect:
        if (TypeRules.androidFeatureTypes.contains(type) && !_hasFeatureOf(type)) {
          return _isLoaded ? "This device's Health Connect does not have it" : 'Checking Health Connect features';
        }
      case HealthPlatformType.appleHealth:
        final minimum = TypeRules.iosMinimumVersion[type];
        final version = iosMajorVersion;
        // An unknown version is not held against the type: the plugin then reports it if needed.
        if (minimum != null && version != null && version < minimum) return 'Needs iOS $minimum or later';
    }
    return null;
  }

  /// The major version in an iOS `Platform.operatingSystemVersion`, such as 17 in
  /// "Version 17.2 (Build 21C62)", or null if there is none.
  static int? parseIosMajorVersion(String operatingSystemVersion) {
    final match =
        RegExp(r'Version (\d+)').firstMatch(operatingSystemVersion) ??
        RegExp(r'(\d+)').firstMatch(operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Whether the device's Health Connect has the feature of one of [TypeRules.androidFeatureTypes].
  bool _hasFeatureOf(HealthDataType type) => switch (type) {
    HealthDataType.SKIN_TEMPERATURE => _skinTemperatureAvailable,
    HealthDataType.MINDFULNESS => _mindfulnessAvailable,
    HealthDataType.ACTIVITY_INTENSITY => _activityIntensityAvailable,
    _ => true,
  };

  /// One refresh: the Health Connect status (Android), then the feature checks. Never throws.
  Future<void> _load() async {
    Object? failure;
    // Each check is caught on its own, so one failure leaves the other flags intact.
    Future<T> attempt<T>(Future<T> Function() check, T fallback) async {
      try {
        return await check();
      } catch (error) {
        failure ??= error;
        return fallback;
      }
    }

    try {
      if (platform == null) {
        failure = UnsupportedError('The health plugin supports Android and iOS only.');
      } else if (isAndroid) {
        // getHealthConnectSdkStatus catches its own failures and returns null, so null is an error.
        _sdkStatus = await attempt(health.getHealthConnectSdkStatus, null);
        if (_sdkStatus == null) failure ??= StateError('Could not read the Health Connect SDK status.');
      }
      // Without Health Connect every feature call would fail, so the checks are skipped. On iOS
      // the plugin answers them without a platform call.
      final ready = isIOS || _sdkStatus == HealthConnectSdkStatus.sdkAvailable;
      final flags = !ready
          ? List<bool>.filled(7, false)
          : await Future.wait([
              attempt(health.isHealthDataHistoryAvailable, false),
              attempt(health.isHealthDataHistoryAuthorized, false),
              attempt(health.isHealthDataInBackgroundAvailable, false),
              attempt(health.isHealthDataInBackgroundAuthorized, false),
              attempt(health.isSkinTemperatureAvailable, false),
              attempt(health.isMindfulnessSessionAvailable, false),
              attempt(health.isActivityIntensityAvailable, false),
            ]);
      _historyAvailable = flags[0];
      _historyAuthorized = flags[1];
      _backgroundAvailable = flags[2];
      _backgroundAuthorized = flags[3];
      _skinTemperatureAvailable = flags[4];
      _mindfulnessAvailable = flags[5];
      _activityIntensityAvailable = flags[6];
    } catch (error) {
      failure ??= error;
    }
    _lastError = failure;
    _isLoaded = true;
    if (!_disposed) notifyListeners();
  }

  /// The platform the plugin runs on, from `dart:io` as the plugin itself decides. On other hosts,
  /// Flutter's target platform: Android under `flutter test`, so widget tests see Health Connect.
  static HealthPlatformType? _detectPlatform() {
    if (Platform.isAndroid) return HealthPlatformType.googleHealthConnect;
    if (Platform.isIOS) return HealthPlatformType.appleHealth;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => HealthPlatformType.googleHealthConnect,
      TargetPlatform.iOS => HealthPlatformType.appleHealth,
      _ => null,
    };
  }

  /// The running iOS version; null on any other OS, also when a test pretends to run on iOS.
  static int? _detectIosMajorVersion() => Platform.isIOS ? parseIosMajorVersion(Platform.operatingSystemVersion) : null;
}
