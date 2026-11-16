/// Test harness for the shared widgets: the expressive theme, the app's services around a scripted
/// [LookupHealth], and a phone-sized window.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';

import '../../core/support/fake_health.dart';

/// A [FakeHealth] that also answers `getHealthDataByUUID` and `deleteByUUID` from fields, and records
/// the calls.
class LookupHealth extends FakeHealth {
  /// What `getHealthDataByUUID` finds, by UUID; a missing UUID returns null.
  final Map<String, HealthDataPoint> records = {};

  /// The UUIDs `deleteByUUID` deletes (returns true for); others return false.
  final Set<String> deletable = {};

  /// Thrown by `getHealthDataByUUID` when set.
  Object? lookupError;

  /// Thrown by `deleteByUUID` when set.
  Object? deleteError;

  /// When set, both calls wait for it to complete before they answer, so tests can see progress.
  Completer<void>? hold;

  /// The `getHealthDataByUUID` calls made.
  final List<(String, HealthDataType)> lookups = [];

  /// The `deleteByUUID` calls made.
  final List<(String, HealthDataType?)> deletions = [];

  @override
  Future<HealthDataPoint?> getHealthDataByUUID({required String uuid, required HealthDataType type}) async {
    lookups.add((uuid, type));
    await hold?.future;
    if (lookupError case final error?) throw error;
    return records[uuid];
  }

  @override
  Future<bool> deleteByUUID({required String uuid, HealthDataType? type}) async {
    deletions.add((uuid, type));
    await hold?.future;
    if (deleteError case final error?) throw error;
    return deletable.remove(uuid);
  }
}

/// The app's services around [health] on [platform], without a capability refresh.
AppServices testServices(Health health, {HealthPlatformType platform = HealthPlatformType.googleHealthConnect}) {
  final capabilities = PlatformCapabilities(
    health,
    platform: platform,
    iosMajorVersion: platform == HealthPlatformType.appleHealth ? 18 : null,
  );
  return AppServices(
    health: health,
    capabilities: capabilities,
    catalog: TypeCatalog(capabilities),
    settings: PluginSettings(health),
    recentWrites: RecentWrites(),
  );
}

/// [child] on a page with the light expressive theme (or [theme]), inside [services] (an `AppScope`)
/// and [destination] (an `AppNavigation`) when given. With [scrollable] the page scrolls, for tall
/// content.
Widget sharedTestApp(
  Widget child, {
  AppServices? services,
  ValueNotifier<AppDestination>? destination,
  bool scrollable = false,
  ThemeData? theme,
}) {
  Widget app = MaterialApp(
    theme: theme ?? ExpressiveTheme.light(),
    home: Scaffold(
      body: scrollable ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: child) : child,
    ),
  );
  if (destination != null) app = AppNavigation(notifier: destination, child: app);
  if (services != null) app = AppScope(services: services, child: app);
  return app;
}

/// A button labelled [label] that runs [onPressed] with a context under the app's navigator, for
/// opening sheets and dialogs.
Widget launcher(String label, void Function(BuildContext context) onPressed) => Builder(
  builder: (context) => Center(
    child: TextButton(onPressed: () => onPressed(context), child: Text(label)),
  ),
);

/// Makes the test window phone-sized, 360 × 800 dp (or [size]) at three pixels per dp, until the test
/// ends.
void usePhoneSize(WidgetTester tester, {Size size = const Size(360, 800)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
