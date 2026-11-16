/// The header above a section of a page.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_typography.dart';

/// A section header: an emphasized [title], an optional [subtitle] under it and an optional [trailing]
/// widget (a button or a status) at the end. Marked as a header for screen readers.
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 24, bottom: 12),
  });

  /// The section's name.
  final String title;

  /// One or two lines on what the section shows.
  final String? subtitle;

  /// A widget at the end of the header.
  final Widget? trailing;

  /// The space around the header: generous above, to separate sections, and none at the sides, so the
  /// title lines up with the page title and the content.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLargeEmphasized.copyWith(color: scheme.onSurface)),
                ),
                if (subtitle case final subtitle?)
                  Text(subtitle, style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
