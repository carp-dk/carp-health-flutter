/// Explanations on demand: a small info button that opens a sheet with the details a screen leaves out to
/// stay minimal.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_typography.dart';

/// A compact info icon that opens [showInfoSheet] with [title], [code] and [message].
///
/// Screens show only labels and values; what a field means, which plugin arguments it sets and how each
/// platform behaves sit behind this button.
class InfoButton extends StatelessWidget {
  /// Creates a button for an explanation of [title].
  const InfoButton({super.key, required this.title, this.message, this.code});

  /// What the explanation is about, such as a section's title.
  final String title;

  /// The explanation.
  final String? message;

  /// A monospace line above the explanation, such as the plugin method or arguments involved.
  final String? code;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'About $title',
    visualDensity: VisualDensity.compact,
    iconSize: 20,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    onPressed: () => showInfoSheet(context, title: title, message: message, code: code),
    icon: const Icon(Icons.info_outline),
  );
}

/// Shows [title], an optional monospace [code] line and an optional [message] in a modal bottom sheet.
Future<void> showInfoSheet(BuildContext context, {required String title, String? message, String? code}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(title, style: theme.textTheme.titleLargeEmphasized),
              if (code case final code?)
                Text(
                  code,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: scheme.primary,
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Courier'],
                  ),
                ),
              if (message case final message?) Text(message, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    },
  );
}
