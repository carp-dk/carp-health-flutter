import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/app/health_example_app.dart';
import 'package:health_example/app/navigation/app_destination.dart';

void main() {
  test('HEALTH_EXAMPLE_TAB names a destination in any case', () {
    expect(AppDestination.fromName('insights'), AppDestination.insights);
    expect(AppDestination.fromName(' SETUP '), AppDestination.setup);
  });

  test('an unknown or missing destination name falls back to the overview', () {
    expect(AppDestination.fromName(null), AppDestination.overview);
    expect(AppDestination.fromName(''), AppDestination.overview);
    expect(AppDestination.fromName('settings'), AppDestination.overview);
  });

  test('HEALTH_EXAMPLE_THEME names a theme mode, else the system one', () {
    expect(HealthExampleApp.themeModeFromName('dark'), ThemeMode.dark);
    expect(HealthExampleApp.themeModeFromName('Light'), ThemeMode.light);
    expect(HealthExampleApp.themeModeFromName(null), ThemeMode.system);
    expect(HealthExampleApp.themeModeFromName('sepia'), ThemeMode.system);
  });

  test('every destination has a label and two icons', () {
    for (final destination in AppDestination.values) {
      expect(destination.label, isNotEmpty);
      expect(destination.icon, isNot(destination.selectedIcon));
    }
  });
}
