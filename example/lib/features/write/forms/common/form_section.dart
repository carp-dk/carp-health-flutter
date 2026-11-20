/// The building blocks of the Write page's forms: a labelled section per plugin argument, laid out in one
/// column on phones and two on wider windows.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// One part of a write form: a [title], an optional [trailing] widget such as a `PlatformBadge`, and the
/// fields ([child]). [parameter] and [caption] document the corresponding plugin argument in source.
class FormSection extends StatelessWidget {
  /// Creates a form section.
  const FormSection({super.key, required this.title, required this.child, this.parameter, this.caption, this.trailing});

  /// What the section sets, such as "When".
  final String title;

  /// The plugin argument or arguments, such as `startTime · endTime`, shown in the info sheet.
  final String? parameter;

  /// The fields.
  final Widget child;

  /// What the argument does, shown in the info sheet.
  final String? caption;

  /// A widget at the end of the title, such as a platform badge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(title, style: theme.textTheme.titleSmallEmphasized.copyWith(color: scheme.onSurface)),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Lays out form [children] in a single column, or in two columns from [twoColumnWidth] on, so the
/// forms use the width of a tablet. The children of a row share its height and line up at the top.
class FormGrid extends StatelessWidget {
  /// Creates the layout of [children].
  const FormGrid({super.key, required this.children, this.spacing = 24, this.twoColumnWidth = 640});

  /// The sections, in reading order.
  final List<Widget> children;

  /// The space between sections, across and down.
  final double spacing;

  /// The narrowest width with two columns.
  final double twoColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < twoColumnWidth) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing, children: children);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: [
            for (var i = 0; i < children.length; i += 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing,
                children: [
                  Expanded(child: children[i]),
                  Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// The surface a form's sections sit on: the expressive card shape in the low surface container colour,
/// so that the filled text fields (highest surface container) and button groups stand out on it.
class FormCard extends StatelessWidget {
  /// Creates the card around [child].
  const FormCard({super.key, required this.child});

  /// The form's sections.
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
    child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), child: child),
  );
}
