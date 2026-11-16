/// A dialog with the full description of an error, for failures first reported in a snack bar.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/errors/error_info.dart';

import 'error_card.dart';

/// Shows [error] in a dialog: the same [ErrorCard] that pages show inline, with the plugin's message,
/// advice and error codes, and a Close button.
///
/// Snack bars have room for a headline only (`ErrorInfo.title`); their "Details" action opens this.
Future<void> showErrorDialog(BuildContext context, Object error) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ErrorCard(error: error),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ),
        ],
      ),
    ),
  ),
);

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
