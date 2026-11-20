/// The controllers of the Setup page, created and disposed together with it.
library;

import 'dart:async';

import 'package:health_example/app/app_scope.dart';

import '../models/runtime_permission.dart';
import 'connect_features_controller.dart';
import 'permissions_controller.dart';
import 'platform_controller.dart';
import 'runtime_permissions_controller.dart';

/// One controller per section of the Setup page that calls the plugin (or `permission_handler`). The
/// plugin settings section needs none: `PluginSettings` from [services] is its controller.
class SetupControllers {
  /// Creates the controllers on the app's [services]; [runtimeGateway] answers the Android runtime
  /// permission calls (`permission_handler` unless a test passes another).
  SetupControllers(this.services, {RuntimePermissionGateway runtimeGateway = const PermissionHandlerGateway()})
    : platform = PlatformController(health: services.health, capabilities: services.capabilities),
      permissions = PermissionsController(
        health: services.health,
        capabilities: services.capabilities,
        catalog: services.catalog,
      ),
      features = ConnectFeaturesController(health: services.health, capabilities: services.capabilities),
      runtime = RuntimePermissionsController(capabilities: services.capabilities, gateway: runtimeGateway);

  /// The app's services: the plugin and the state shared with the other pages.
  final AppServices services;

  /// The platform section: Health Connect's status and `installHealthConnect`.
  final PlatformController platform;

  /// The permissions section: `requestAuthorization`, `hasPermissions`, `getRequestStatusForAuthorization`
  /// and `revokePermissions`.
  final PermissionsController permissions;

  /// The Health Connect features section: the history and background read permissions.
  final ConnectFeaturesController features;

  /// The Android runtime permissions section (`permission_handler`).
  final RuntimePermissionsController runtime;

  /// Starts what the page shows without being asked: the runtime permission statuses (Android) at once,
  /// the platform's status if the app has not read it yet (else only `isHealthConnectAvailable`), and then
  /// the access to the selected types (see `PermissionsController.refresh`).
  Future<void> start() async {
    unawaited(runtime.refresh());
    if (!services.capabilities.isLoaded) {
      await platform.refresh();
    } else {
      await platform.checkHealthConnectAvailable();
    }
    await permissions.refresh();
  }

  /// Reads everything again: on pull to refresh, and when the app resumes, as the user may have changed
  /// permissions in the system settings or in Health Connect, or installed Health Connect, meanwhile. The
  /// access is checked after the platform, whose features decide which types there are to check.
  Future<void> refreshAll() async {
    await Future.wait([platform.refresh(), runtime.refresh()]);
    await permissions.refresh();
  }

  /// Disposes the controllers; calls still running complete without notifying.
  void dispose() {
    platform.dispose();
    permissions.dispose();
    features.dispose();
    runtime.dispose();
  }
}
