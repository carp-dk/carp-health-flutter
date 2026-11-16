/// The controller of the Setup page's Health Connect features section: requests the two extra read
/// permissions, `requestHealthDataHistoryAuthorization` and `requestHealthDataInBackgroundAuthorization`.
/// Whether each feature is available and granted comes from `PlatformCapabilities`.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';

import 'safe_notifier.dart';

/// One of Health Connect's two extra read permissions.
enum ExtraReadPermission {
  /// `READ_HEALTH_DATA_HISTORY`: data older than the 30 days Health Connect allows by default.
  history,

  /// `READ_HEALTH_DATA_IN_BACKGROUND`: reads while the app is in the background.
  background,
}

/// Requests Health Connect's history and background read permissions and refreshes the capabilities
/// afterwards, so every page sees whether they were granted. Android only: on iOS the plugin answers
/// true without asking, as HealthKit has no such permissions.
class ConnectFeaturesController extends ChangeNotifier with SafeNotifier {
  /// Creates the controller for the plugin [health] and the device's [capabilities].
  ConnectFeaturesController({required this.health, required this.capabilities});

  /// The plugin.
  final Health health;

  /// Whether each feature is available and authorized; refreshed after every request.
  final PlatformCapabilities capabilities;

  final Map<ExtraReadPermission, AsyncValue<bool>> _requests = {
    for (final permission in ExtraReadPermission.values) permission: const AsyncIdle(),
  };

  /// The state of the last request of [permission]: true if the plugin reported it granted.
  AsyncValue<bool> requestOf(ExtraReadPermission permission) => _requests[permission]!;

  /// Whether [permission] can be requested on this device (`isHealthDataHistoryAvailable` or
  /// `isHealthDataInBackgroundAvailable`).
  bool isAvailable(ExtraReadPermission permission) => switch (permission) {
    ExtraReadPermission.history => capabilities.historyAvailable,
    ExtraReadPermission.background => capabilities.backgroundAvailable,
  };

  /// Whether [permission] is granted (`isHealthDataHistoryAuthorized` or
  /// `isHealthDataInBackgroundAuthorized`).
  bool isAuthorized(ExtraReadPermission permission) => switch (permission) {
    ExtraReadPermission.history => capabilities.historyAuthorized,
    ExtraReadPermission.background => capabilities.backgroundAuthorized,
  };

  /// Shows Health Connect's dialog for [permission]. The result stays loading until the capabilities
  /// have been refreshed, so the page never shows a stale "not granted" next to a granted request.
  Future<void> request(ExtraReadPermission permission) async {
    if (!capabilities.isAndroid || requestOf(permission).isLoading) return;
    _requests[permission] = const AsyncLoading();
    notifyListeners();
    // Both return false rather than throw when the dialog fails (the plugin logs why), but throw an
    // UnsupportedError when Health Connect is not available.
    final result = await AsyncValue.guard(switch (permission) {
      ExtraReadPermission.history => health.requestHealthDataHistoryAuthorization,
      ExtraReadPermission.background => health.requestHealthDataInBackgroundAuthorization,
    });
    await capabilities.refresh();
    _requests[permission] = result;
    notifyListeners();
  }
}
