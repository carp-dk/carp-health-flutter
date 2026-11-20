/// The controller of the Setup page's Android runtime permissions: activity recognition and location,
/// which the plugin's README asks apps to request with `permission_handler`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/runtime_permission.dart';
import 'safe_notifier.dart';

/// Reads and requests the [RuntimePermission]s through a [RuntimePermissionGateway]. Android only: on
/// iOS nothing is called and every status stays idle.
class RuntimePermissionsController extends ChangeNotifier with SafeNotifier {
  /// Creates the controller for the device's [capabilities], asking [gateway] (`permission_handler`
  /// unless a test passes another).
  RuntimePermissionsController({required this.capabilities, this.gateway = const PermissionHandlerGateway()});

  /// Tells whether this is Android.
  final PlatformCapabilities capabilities;

  /// Where the permission calls go.
  final RuntimePermissionGateway gateway;

  final Map<RuntimePermission, AsyncValue<PermissionStatus>> _statuses = {
    for (final permission in RuntimePermission.values) permission: const AsyncIdle(),
  };
  final Set<RuntimePermission> _requesting = {};
  AsyncValue<bool> _settings = const AsyncIdle();

  /// Whether the permissions apply here: they are Android permissions.
  bool get isSupported => capabilities.isAndroid;

  /// The status of [permission]; while it reloads, the previous status stays available.
  AsyncValue<PermissionStatus> statusOf(RuntimePermission permission) => _statuses[permission]!;

  /// Whether [permission] is being requested, that is Android's dialog for it is open; its status is
  /// loading then too.
  bool isRequesting(RuntimePermission permission) => _requesting.contains(permission);

  /// The result of the last [openSettings]: whether the settings opened.
  AsyncValue<bool> get settings => _settings;

  /// Reads the status of every permission (`Permission.status`), for example when the app resumes from
  /// the system settings. A permission being requested is left to its request, which returns its status.
  Future<void> refresh() async {
    if (!isSupported) return;
    await Future.wait([
      for (final permission in RuntimePermission.values)
        if (!_requesting.contains(permission)) _run(permission, gateway.status),
    ]);
  }

  /// Asks the user for [permission] (`Permission.request`). Android shows no dialog for a permission
  /// the user denied twice; the status then reads permanently denied and [openSettings] is the way on.
  Future<void> request(RuntimePermission permission) async {
    if (!isSupported || _requesting.contains(permission)) return;
    _requesting.add(permission);
    await _run(permission, gateway.request);
    _requesting.remove(permission);
    notifyListeners();
  }

  /// Opens the app's page in the system settings (`openAppSettings`). The statuses are read again when
  /// the app resumes, see [refresh].
  Future<void> openSettings() async {
    if (!isSupported || _settings.isLoading) return;
    _settings = const AsyncLoading();
    notifyListeners();
    _settings = await AsyncValue.guard(gateway.openSettings);
    notifyListeners();
  }

  Future<void> _run(RuntimePermission permission, Future<PermissionStatus> Function(Permission) call) async {
    _statuses[permission] = statusOf(permission).toLoading();
    notifyListeners();
    _statuses[permission] = await AsyncValue.guard(() => call(permission.permission));
    notifyListeners();
  }
}
