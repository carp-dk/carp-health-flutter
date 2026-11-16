/// The health plugin's example app: a Material 3 Expressive tour of everything the plugin does, by
/// feature (Overview, Read, Insights, Write and Setup; see `lib/features`).
///
/// This file shows the setup every app using the plugin needs: one [Health] instance, configured before
/// use. The rest of the app reaches it through `AppScope`.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/app/health_example_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app uses the plugin through this one instance; AppScope hands it to every feature.
  final health = Health();
  try {
    // Looks up the device id (Health.deviceId) that read data points carry; call it before using the plugin.
    await health.configure();
  } catch (error, stackTrace) {
    // The app still works without it: the plugin looks the device id up again on the first read.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'health example',
        context: ErrorDescription('while configuring the health plugin'),
      ),
    );
  }

  runApp(HealthExampleApp(services: AppServices.create(health)));
}
