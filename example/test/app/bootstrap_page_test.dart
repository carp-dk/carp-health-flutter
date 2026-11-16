import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/app/bootstrap_page.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';

/// A [Health] whose Health Connect status arrives only when the test completes [status]; the feature
/// checks after it answer at once.
class _GatedHealth extends Health {
  final Completer<HealthConnectSdkStatus?> status = Completer();

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() => status.future;
}

void main() {
  // Created inside each test: futures must belong to the test's fake-async zone to complete under pump.
  late _GatedHealth health;
  late AppServices services;

  Widget app({Duration timeout = const Duration(seconds: 15)}) {
    health = _GatedHealth();
    final capabilities = PlatformCapabilities(health, platform: HealthPlatformType.googleHealthConnect);
    services = AppServices(
      health: health,
      capabilities: capabilities,
      catalog: TypeCatalog(capabilities),
      settings: PluginSettings(health),
      recentWrites: RecentWrites(),
    );
    addTearDown(services.dispose);
    return AppScope(
      services: services,
      child: MaterialApp(
        theme: ExpressiveTheme.light(),
        home: BootstrapPage(timeout: timeout, child: const Text('App')),
      ),
    );
  }

  testWidgets('shows the splash until the platform checks are done', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Checking Health Connect…'), findsOneWidget);
    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
    expect(find.text('App'), findsNothing);

    health.status.complete(HealthConnectSdkStatus.sdkUnavailable);
    await tester.pumpAndSettle();

    expect(find.text('App'), findsOneWidget);
    expect(find.text('Checking Health Connect…'), findsNothing);
    expect(services.capabilities.isLoaded, isTrue);
  });

  testWidgets('starts the app anyway when the checks hang', (tester) async {
    await tester.pumpWidget(app(timeout: const Duration(seconds: 2)));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('App'), findsOneWidget);
    expect(services.capabilities.isLoaded, isFalse);
  });
}
