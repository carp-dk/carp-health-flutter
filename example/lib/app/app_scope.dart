/// Dependency injection for the example app: [AppServices] holds the plugin instance and the app-wide
/// state built on it, and [AppScope] hands them to every widget, route, sheet and dialog of the app.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/core/writes/recent_writes.dart';

/// The app-wide services: the one [Health] instance through which the whole app uses the plugin, and
/// the shared state built on it.
///
/// Created once by `main` (after `Health.configure`) and alive as long as the app. Feature controllers
/// take what they need from here (see [AppScope.of]) and call the plugin through [health] themselves.
@immutable
class AppServices {
  /// Creates the services from their parts; [AppServices.create] wires them up around a [Health].
  const AppServices({
    required this.health,
    required this.capabilities,
    required this.catalog,
    required this.settings,
    required this.recentWrites,
  });

  /// Creates the services around [health], which should already be configured (`Health.configure`).
  /// Nothing is asked from the plugin yet: `BootstrapPage` calls [PlatformCapabilities.refresh].
  factory AppServices.create(Health health) {
    final capabilities = PlatformCapabilities(health);
    return AppServices(
      health: health,
      capabilities: capabilities,
      catalog: TypeCatalog(capabilities),
      settings: PluginSettings(health),
      recentWrites: RecentWrites(),
    );
  }

  /// The plugin: every plugin call of the app goes through this instance.
  final Health health;

  /// The platform (Health Connect or Apple Health), its status and its optional features.
  final PlatformCapabilities capabilities;

  /// The data types this device supports, grouped and filtered for reading, writing and deleting.
  final TypeCatalog catalog;

  /// The plugin's read settings (`Health.pageSize`, `Health.isolateMode`).
  final PluginSettings settings;

  /// What this app wrote in this session, with the UUIDs to look the records up or delete them.
  final RecentWrites recentWrites;

  /// Releases the change notifiers; for tests that create services of their own.
  void dispose() {
    capabilities.dispose();
    settings.dispose();
    recentWrites.dispose();
  }
}

/// Makes [services] available to the widgets below: `AppScope.of(context)`.
///
/// `HealthExampleApp` places it above the `MaterialApp`, so that pushed pages, bottom sheets and dialogs
/// (which live on the navigator, not under the page that opened them) can reach the services too.
class AppScope extends InheritedWidget {
  /// Provides [services] to [child] and everything below it.
  const AppScope({super.key, required this.services, required super.child});

  /// The services provided.
  final AppServices services;

  /// The services of the nearest [AppScope].
  ///
  /// It registers no dependency (the services never change during the app's life), so it is safe to
  /// call from `State.initState`, which is where the feature pages create their controllers.
  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget: HealthExampleApp provides one around the app.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
