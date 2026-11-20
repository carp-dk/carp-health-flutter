/// The full description of an error, on demand: from an error card's info button or a snack bar's
/// "Details".
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/shared/visuals/error_visuals.dart';
import 'package:health_example/shared/visuals/monospace.dart';

/// Shows [error] in a dialog: its title, the plugin's whole message, advice ([ErrorInfo.hint]) and
/// error codes, with "Open Setup" for a permission error and Close.
///
/// Error cards show the first line of the message only, and snack bars the title.
Future<void> showErrorDialog(BuildContext context, Object error) {
  final info = ErrorInfo.from(error);
  // AppNavigation exists in the app but not around a widget under test.
  final canOpenSetup = info.isPermission && context.getInheritedWidgetOfExactType<AppNavigation>() != null;
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final muted = theme.colorScheme.onSurfaceVariant;
      return AlertDialog(
        icon: Icon(info.icon),
        title: Text(info.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(info.message),
              if (info.hint case final hint?) Text(hint, style: theme.textTheme.bodySmall!.copyWith(color: muted)),
              if (info.codes.isNotEmpty)
                Text(info.codes.join(' · '), style: theme.textTheme.labelSmall!.copyWith(color: muted).monospace),
            ],
          ),
        ),
        actions: [
          if (canOpenSetup)
            TextButton(
              onPressed: () => AppNavigation.goTo(context, AppDestination.setup),
              child: const Text('Open Setup'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
    },
  );
}

/// Shows a floating snack bar with [message] (by default the error's headline) and a "Details" action
/// that opens [showErrorDialog]. Does nothing where there is no `ScaffoldMessenger`.
///
/// The action opens the dialog on [context]'s root navigator, which outlives the page that failed,
/// as the snack bar may still show after that page closed.
void showErrorSnackBar(BuildContext context, Object error, {String? message}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.maybeOf(context, rootNavigator: true);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(message ?? ErrorInfo.from(error).title),
      action: navigator == null
          ? null
          : SnackBarAction(label: 'Details', onPressed: () => showErrorDialog(navigator.context, error)),
    ),
  );
}
