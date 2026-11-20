/// The controller of the Setup page's platform section: Health Connect's status and features (through
/// `PlatformCapabilities.refresh`, which calls `getHealthConnectSdkStatus` and the feature checks),
/// `isHealthConnectAvailable`, `isDataTypeAvailable` and `installHealthConnect`.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';

import 'safe_notifier.dart';

/// A data type of the platform that this device cannot use, and why.
typedef UnsupportedType = ({HealthDataType type, String reason});

/// Refreshes what the platform offers and installs Health Connect where that helps.
///
/// The capabilities are app-wide (the type lists of every feature follow them), so a refresh here
/// updates the whole app.
class PlatformController extends ChangeNotifier with SafeNotifier {
  /// Creates the controller for the plugin [health] and the device's [capabilities].
  PlatformController({required this.health, required this.capabilities});

  /// The plugin.
  final Health health;

  /// The platform's status and features, which [refresh] updates.
  final PlatformCapabilities capabilities;

  bool _refreshing = false;
  bool? _healthConnectAvailable;
  AsyncValue<void> _install = const AsyncIdle();

  /// The state of the platform checks: loading while a refresh runs (this controller's or one started
  /// elsewhere, such as the app's start), an error when the last refresh could not check everything
  /// (`PlatformCapabilities.lastError`), and done otherwise.
  AsyncValue<void> get status {
    if (_refreshing || capabilities.isRefreshing || !capabilities.isLoaded) return const AsyncLoading();
    final error = capabilities.lastError;
    return error == null ? const AsyncData(null) : AsyncError(error, StackTrace.empty);
  }

  /// The state of the last `installHealthConnect` call.
  AsyncValue<void> get install => _install;

  /// The id of this device that the data points read here carry as `sourceDeviceId` (`Health.deviceId`):
  /// `Build.ID` on Android, `identifierForVendor` on iOS, and "unknown" until `Health.configure` (which
  /// `main` calls) or the first read has looked it up.
  String get deviceId => health.deviceId;

  /// What `Health.isHealthConnectAvailable` answered at the last [refresh]: whether the plugin can use
  /// Health Connect (always true on iOS); null before the first refresh.
  bool? get healthConnectAvailable => _healthConnectAvailable;

  /// The data types the plugin has on this platform, asked type by type with `Health.isDataTypeAvailable`
  /// (which looks them up in `dataTypeKeysAndroid` or `dataTypeKeysIOS`).
  List<HealthDataType> get platformTypes => [
    for (final type in HealthDataType.values)
      if (health.isDataTypeAvailable(type)) type,
  ];

  /// The number of data types of this platform (`dataTypeKeysAndroid` or `dataTypeKeysIOS`).
  int get platformTypeCount => capabilities.platform == null ? 0 : platformTypes.length;

  /// The data types of this platform the device cannot use, with the reason: a Health Connect feature
  /// it lacks (Android) or an iOS version that is too old.
  List<UnsupportedType> get unsupportedTypes => [
    if (capabilities.platform != null)
      for (final type in platformTypes)
        if (capabilities.unsupportedReason(type) case final reason?) (type: type, reason: reason),
  ];

  /// Asks the plugin again for the platform's status and features. Never throws: a failed check is
  /// kept as `PlatformCapabilities.lastError` and shows in [status].
  Future<void> refresh() async {
    _refreshing = true;
    notifyListeners();
    await capabilities.refresh();
    await checkHealthConnectAvailable();
    _refreshing = false;
    notifyListeners();
  }

  /// Asks `Health.isHealthConnectAvailable` whether the plugin can use Health Connect. Never throws: a
  /// failure counts as not available, and the status shows why.
  Future<void> checkHealthConnectAvailable() async {
    try {
      _healthConnectAvailable = await health.isHealthConnectAvailable();
    } catch (_) {
      _healthConnectAvailable = false;
    }
    notifyListeners();
  }

  /// Opens the store to install or update Health Connect (`installHealthConnect`), then refreshes the
  /// status. Android only; it only helps where the status asks for it, on Android 13 and lower.
  ///
  /// The call returns once the store has opened: the page refreshes again when the app resumes.
  Future<void> installHealthConnect() async {
    if (!capabilities.isAndroid) return;
    _install = const AsyncLoading();
    notifyListeners();
    _install = await AsyncValue.guard(health.installHealthConnect);
    notifyListeners();
    await refresh();
  }
}
