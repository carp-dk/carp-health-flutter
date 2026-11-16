/// The app's top-level destinations, shown in the navigation bar or rail.
library;

import 'package:flutter/material.dart';

/// A top-level destination of the app, with its label and icons.
enum AppDestination {
  /// The platform at a glance: status, authorization and today's highlights.
  overview('Overview', Icons.space_dashboard_outlined, Icons.space_dashboard),

  /// Reading data: queries, lookups by UUID and change tracking.
  read('Read', Icons.monitor_heart_outlined, Icons.monitor_heart),

  /// Aggregated data: interval buckets and step totals.
  insights('Insights', Icons.analytics_outlined, Icons.analytics),

  /// Writing and deleting data.
  write('Write', Icons.edit_note_outlined, Icons.edit_note),

  /// Platform status, permissions, Health Connect features and plugin settings.
  setup('Setup', Icons.tune_outlined, Icons.tune);

  const AppDestination(this.label, this.icon, this.selectedIcon);

  /// The name in the navigation bar or rail.
  final String label;

  /// The icon while not selected (outlined).
  final IconData icon;

  /// The icon while selected (filled).
  final IconData selectedIcon;

  /// The destination named [name] (as in `--dart-define=HEALTH_EXAMPLE_TAB=insights`, any case), or
  /// [overview] when [name] is null, empty or unknown.
  static AppDestination fromName(String? name) {
    final wanted = name?.trim().toLowerCase();
    return values.firstWhere((destination) => destination.name == wanted, orElse: () => overview);
  }
}
