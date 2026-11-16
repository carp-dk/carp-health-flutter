/// The root widget of the example app: services, navigation, themes and the first screen.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'app_scope.dart';
import 'bootstrap_page.dart';
import 'navigation/app_destination.dart';
import 'navigation/app_navigation.dart';

/// The example app: provides the [services] ([AppScope]) and the selected destination ([AppNavigation])
/// above a `MaterialApp` with the light and dark Material 3 Expressive themes, starting on the
/// [BootstrapPage] splash.
///
/// Two developer settings, for screenshots and for working on one feature, can be passed with
/// `--dart-define`:
/// * `HEALTH_EXAMPLE_TAB=overview|read|insights|write|setup` picks the destination shown first;
/// * `HEALTH_EXAMPLE_THEME=light|dark|system` forces a theme mode.
class HealthExampleApp extends StatefulWidget {
  /// Creates the app around [services]; [initialDestination] and [themeMode] override the
  /// `--dart-define` settings (for tests).
  const HealthExampleApp({super.key, required this.services, this.initialDestination, this.themeMode});

  /// The plugin and the app-wide state.
  final AppServices services;

  /// The destination shown first; by default `HEALTH_EXAMPLE_TAB`, else the overview.
  final AppDestination? initialDestination;

  /// Light, dark or following the system; by default `HEALTH_EXAMPLE_THEME`, else the system's.
  final ThemeMode? themeMode;

  /// The `HEALTH_EXAMPLE_TAB` setting.
  static const String tabSetting = String.fromEnvironment('HEALTH_EXAMPLE_TAB');

  /// The `HEALTH_EXAMPLE_THEME` setting.
  static const String themeSetting = String.fromEnvironment('HEALTH_EXAMPLE_THEME');

  /// The theme mode named [name] (`light`, `dark` or `system`, any case); [ThemeMode.system] otherwise.
  static ThemeMode themeModeFromName(String? name) {
    final wanted = name?.trim().toLowerCase();
    return ThemeMode.values.firstWhere((mode) => mode.name == wanted, orElse: () => ThemeMode.system);
  }

  @override
  State<HealthExampleApp> createState() => _HealthExampleAppState();
}

class _HealthExampleAppState extends State<HealthExampleApp> {
  late final ValueNotifier<AppDestination> _destination = ValueNotifier(
    widget.initialDestination ?? AppDestination.fromName(HealthExampleApp.tabSetting),
  );

  // Generating the expressive schemes is not free: build each theme once.
  late final ThemeData _light = ExpressiveTheme.light();
  late final ThemeData _dark = ExpressiveTheme.dark();

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: AppNavigation(
        notifier: _destination,
        child: MaterialApp(
          title: 'Health example',
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          themeMode: widget.themeMode ?? HealthExampleApp.themeModeFromName(HealthExampleApp.themeSetting),
          home: const BootstrapPage(),
        ),
      ),
    );
  }
}
