/// A small fact about a plugin call, such as the time a read took, as the Read page's summaries list them.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// A fact such as "312 ms" or "4 pages": an [icon] and a short [text] on a pill tinted with the ambient
/// content colour, so that it suits whichever `ExpressiveCard` variant it sits on.
class FactPill extends StatelessWidget {
  /// Creates a fact pill.
  const FactPill({super.key, required this.icon, required this.text});

  /// What the fact is about.
  final IconData icon;

  /// The fact, in a few words.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ExpressiveCard puts its content colour on the icon theme.
    final color = IconTheme.of(context).color ?? theme.colorScheme.onSurface;
    return DecoratedBox(
      decoration: ShapeDecoration(color: color.withValues(alpha: 0.1), shape: ExpressiveShapes.stadium),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 12, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(icon, size: 16, color: color),
            Flexible(
              child: Text(text, style: theme.textTheme.labelLarge!.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
