/// One labelled option of a form card on the Read page.
library;

import 'package:flutter/material.dart';

/// An option: a short [label] over its control ([child]). What the option does, and the plugin argument it
/// sets, are in the info button of the card it is on.
class OptionBlock extends StatelessWidget {
  /// Creates an option block.
  const OptionBlock({super.key, required this.label, required this.child});

  /// What the option is, such as "Limit per type".
  final String label;

  /// The control.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(label, style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        child,
      ],
    );
  }
}
