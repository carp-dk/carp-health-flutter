/// App-wide navigation between the top-level destinations, usable from anywhere in the app.
library;

import 'package:flutter/widgets.dart';

import 'app_destination.dart';

/// Holds the selected [AppDestination] for the whole app, so that any widget, page, sheet or dialog can
/// switch destinations ([goTo]) and the shell rebuilds ([of]).
///
/// `HealthExampleApp` places it above the `MaterialApp`, which owns the [notifier].
class AppNavigation extends InheritedNotifier<ValueNotifier<AppDestination>> {
  /// Provides the destination held by [notifier] to [child] and everything below it.
  const AppNavigation({super.key, required ValueNotifier<AppDestination> super.notifier, required super.child});

  /// The selected destination; the calling widget rebuilds when it changes.
  static AppDestination of(BuildContext context) {
    final navigation = context.dependOnInheritedWidgetOfExactType<AppNavigation>();
    assert(navigation != null, 'No AppNavigation above this widget: HealthExampleApp provides one.');
    return navigation!.notifier!.value;
  }

  /// Shows [destination]. Pages, sheets and dialogs on top of the shell are closed first, so the
  /// destination is visible whatever [context] belongs to (for example the "Read last 24 h" action of
  /// a sheet, or a written record's "View" in Write).
  static void goTo(BuildContext context, AppDestination destination) {
    final navigation = context.getInheritedWidgetOfExactType<AppNavigation>();
    assert(navigation != null, 'No AppNavigation above this widget: HealthExampleApp provides one.');
    Navigator.maybeOf(context, rootNavigator: true)?.popUntil((route) => route.isFirst);
    navigation!.notifier!.value = destination;
  }
}
