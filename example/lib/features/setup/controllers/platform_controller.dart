/// The controller of the Setup page's platform section: Health Connect's status and features (through
/// `PlatformCapabilities.refresh`, which calls `getHealthConnectSdkStatus` and the feature checks) and
/// `installHealthConnect`.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_rules.dart';

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
  AsyncValue<void> _install = const AsyncIdle();

  /// The state of the platform checks: loading while [refresh] runs, an error when the last refresh
  /// could not check everything (`PlatformCapabilities.lastError`), and done otherwise.
  AsyncValue<void> get status {
    if (_refreshing) return const AsyncLoading();
    final error = capabilities.lastError;
    return error == null ? const AsyncData(null) : AsyncError(error, StackTrace.empty);
  }

  /// The state of the last `installHealthConnect` call.
  AsyncValue<void> get install => _install;

  /// The number of data types of this platform (`dataTypeKeysAndroid` or `dataTypeKeysIOS`).
  int get platformTypeCount => switch (capabilities.platform) {
    null => 0,
    final platform => TypeRules.platformTypes(platform).length,
  };

  /// The data types of this platform the device cannot use, with the reason: a Health Connect feature
  /// it lacks (Android) or an iOS version that is too old.
  List<UnsupportedType> get unsupportedTypes => switch (capabilities.platform) {
    null => const [],
    final platform => [
      for (final type in TypeRules.platformTypes(platform))
        if (capabilities.unsupportedReason(type) case final reason?) (type: type, reason: reason),
    ],
  };

  /// Asks the plugin again for the platform's status and features. Never throws: a failed check is
  /// kept as `PlatformCapabilities.lastError` and shows in [status].
  Future<void> refresh() async {
    _refreshing = true;
    notifyListeners();
    await capabilities.refresh();
    _refreshing = false;
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
