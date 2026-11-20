/// Setup: everything the plugin needs before the app can read and write health data, and how it reads.
///
/// * Platform: Health Connect's status (`getHealthConnectSdkStatus`) and `installHealthConnect` where it
///   helps on Android, the iOS version on iOS, and the platform's data types this device supports.
/// * Permissions: `requestAuthorization`, `hasPermissions` (per category and per type),
///   `getRequestStatusForAuthorization` (iOS) and `revokePermissions` (Android) for all types or one
///   category, asking for read or read and write access (`PermissionPlan` lowers read-only types to read).
/// * Health Connect features (Android): `isHealthDataHistoryAvailable` / `Authorized` and
///   `requestHealthDataHistoryAuthorization`, the same for reading in the background, and
///   `isSkinTemperatureAvailable`, `isMindfulnessSessionAvailable` and `isActivityIntensityAvailable`.
/// * Runtime permissions (Android): activity recognition and location with `permission_handler`.
/// * Plugin settings: `Health.pageSize`, `Health.isolateMode` and `Health.deviceId`.
///
/// Everything is read again on pull to refresh and whenever the app resumes, as permissions change in the
/// system settings and in Health Connect, outside the app.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';

import 'controllers/setup_controllers.dart';
import 'models/runtime_permission.dart';
import 'sections/features_section.dart';
import 'sections/permissions_section.dart';
import 'sections/platform_section.dart';
import 'sections/plugin_settings_section.dart';
import 'sections/runtime_permissions_section.dart';

/// The Setup destination: one section per topic, with the platform's own sections first and the notes on
/// what only the other platform has last.
class SetupPage extends StatefulWidget {
  /// Creates the page; [runtimeGateway] answers the Android runtime permission calls, `permission_handler`
  /// unless a test passes another.
  const SetupPage({super.key, this.runtimeGateway = const PermissionHandlerGateway()});

  /// Where the runtime permission calls go.
  final RuntimePermissionGateway runtimeGateway;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final SetupControllers _controllers;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be read here: the services live as long as the app.
    _controllers = SetupControllers(AppScope.of(context), runtimeGateway: widget.runtimeGateway);
    unawaited(_controllers.start());
    // The user may have changed permissions in the system settings or in Health Connect, or installed
    // Health Connect, while the app was in the background.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_controllers.refreshAll()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controllers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllers = _controllers;
    final permissions = controllers.permissions;
    final isIOS = controllers.services.capabilities.isIOS;
    final androidSections = [
      FeaturesSection(controller: controllers.features),
      RuntimePermissionsSection(controller: controllers.runtime),
    ];
    final settings = PluginSettingsSection(settings: controllers.services.settings, platform: controllers.platform);
    return ExpressivePage(
      title: 'Setup',
      onRefresh: controllers.refreshAll,
      slivers: [
        for (final section in [
          PlatformSection(controller: controllers.platform),
          PermissionsSection(controller: permissions),
          // The sections of the other platform only explain what this one does instead: they go last.
          if (isIOS) ...[settings, ...androidSections] else ...[...androidSections, settings],
        ])
          SliverToBoxAdapter(child: section),
      ],
    );
  }
}
