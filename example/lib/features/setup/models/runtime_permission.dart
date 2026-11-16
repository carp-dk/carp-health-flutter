/// The Android runtime permissions that the plugin's README asks apps to request with the
/// `permission_handler` package, next to the Health Connect permissions: activity recognition and
/// location. The health plugin does not request them itself.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';
import 'package:permission_handler/permission_handler.dart';

/// An Android runtime permission the README asks for, with what it is needed for.
enum RuntimePermission {
  /// `ACTIVITY_RECOGNITION`, which the README asks for before reading fitness data such as steps.
  activityRecognition(
    'Activity recognition',
    'android.permission.ACTIVITY_RECOGNITION',
    Icons.directions_run,
    'The README asks for it before reading fitness data such as steps.',
  ),

  /// `ACCESS_FINE_LOCATION` (and coarse), needed only to record workout routes.
  location(
    'Location',
    'android.permission.ACCESS_FINE_LOCATION',
    Icons.location_on,
    'Needed only to record workout routes, not for workouts or their distance.',
  );

  const RuntimePermission(this.label, this.manifestName, this.icon, this.purpose);

  /// The permission's name.
  final String label;

  /// The permission the app's `AndroidManifest.xml` declares.
  final String manifestName;

  /// An icon for the permission.
  final IconData icon;

  /// Why a health app asks for it.
  final String purpose;

  /// The `permission_handler` permission.
  Permission get permission => switch (this) {
    activityRecognition => Permission.activityRecognition,
    location => Permission.location,
  };
}

/// The `permission_handler` calls the Setup page makes, behind an interface so that tests can answer
/// them without the platform.
abstract interface class RuntimePermissionGateway {
  /// The current status of [permission] (`Permission.status`).
  Future<PermissionStatus> status(Permission permission);

  /// Asks the user for [permission] (`Permission.request`) and returns the new status.
  Future<PermissionStatus> request(Permission permission);

  /// Opens the app's page in the system settings (`openAppSettings`), where a permanently denied
  /// permission can still be granted; false if it could not be opened.
  Future<bool> openSettings();
}

/// The [RuntimePermissionGateway] of the app: the real `permission_handler`.
class PermissionHandlerGateway implements RuntimePermissionGateway {
  /// Creates the gateway.
  const PermissionHandlerGateway();

  @override
  Future<PermissionStatus> status(Permission permission) => permission.status;

  @override
  Future<PermissionStatus> request(Permission permission) => permission.request();

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// What the page can do about a runtime permission in its current status.
enum RuntimePermissionAction {
  /// Nothing: granted, or restricted by the system.
  none,

  /// Ask the user (`Permission.request`).
  request,

  /// Send the user to the system settings (`openAppSettings`): Android shows no dialog any more.
  openSettings,
}

/// How the page shows a [PermissionStatus] and what it offers.
@immutable
class RuntimeStatusView {
  /// Creates the view of a status.
  const RuntimeStatusView({required this.label, required this.tone, required this.action});

  /// Describes [status].
  factory RuntimeStatusView.of(PermissionStatus status) => switch (status) {
    PermissionStatus.granted => const RuntimeStatusView(
      label: 'Granted',
      tone: StatusTone.success,
      action: RuntimePermissionAction.none,
    ),
    PermissionStatus.denied => const RuntimeStatusView(
      label: 'Not granted',
      tone: StatusTone.warning,
      action: RuntimePermissionAction.request,
    ),
    // From Android 11 on, a permission denied twice is permanently denied: no dialog shows any more.
    PermissionStatus.permanentlyDenied => const RuntimeStatusView(
      label: 'Denied',
      tone: StatusTone.error,
      action: RuntimePermissionAction.openSettings,
    ),
    PermissionStatus.restricted => const RuntimeStatusView(
      label: 'Restricted',
      tone: StatusTone.error,
      action: RuntimePermissionAction.none,
    ),
    PermissionStatus.limited => const RuntimeStatusView(
      label: 'Limited',
      tone: StatusTone.info,
      action: RuntimePermissionAction.request,
    ),
    PermissionStatus.provisional => const RuntimeStatusView(
      label: 'Provisional',
      tone: StatusTone.info,
      action: RuntimePermissionAction.none,
    ),
  };

  /// The status in a word or two.
  final String label;

  /// How the status reads.
  final StatusTone tone;

  /// What the page offers.
  final RuntimePermissionAction action;
}
