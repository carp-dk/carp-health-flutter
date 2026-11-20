/// A one-line note inside a write form, such as "Ignored on iOS" or why the write would fail.
library;

import 'package:flutter/material.dart';

/// An [icon] and a short line in the muted text colour. With [warning] both take the error colour, for
/// input the plugin will reject.
class FormNote extends StatelessWidget {
  /// Creates a note saying [text].
  const FormNote({super.key, required this.text, this.icon = Icons.info_outline, this.warning = false});

  /// The note, one short line.
  final String text;

  /// The icon before the note.
  final IconData icon;

  /// Whether the note warns about the input.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warning ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: color),
        Flexible(
          child: Text(text, style: theme.textTheme.bodyMedium!.copyWith(color: color)),
        ),
      ],
    );
  }
}
