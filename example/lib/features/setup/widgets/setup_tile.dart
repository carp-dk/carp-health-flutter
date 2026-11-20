/// The row the Setup page shows one setting, permission or feature in.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// A shaped icon beside a [title] (with an optional [info] button and platform [badge]), a short
/// [subtitle], the [status] (usually a `StatusPill`) and a [footer] for actions.
///
/// The status sits under the title rather than at the end, so long titles and pills both fit on phones.
class SetupTile extends StatelessWidget {
  /// Creates a tile.
  const SetupTile({
    super.key,
    required this.leading,
    required this.title,
    this.info,
    this.subtitle,
    this.badge,
    this.status = const [],
    this.footer,
  });

  /// The icon at the start, usually a `ShapedIcon`.
  final Widget leading;

  /// What the tile is about.
  final String title;

  /// The explanation on demand, usually an `InfoButton` with the plugin call, next to the title.
  final Widget? info;

  /// One short line, such as why something is not available.
  final String? subtitle;

  /// A `PlatformBadge` after the title, for something one platform has.
  final Widget? badge;

  /// The state, usually `StatusPill`s; wrapped onto more lines where needed.
  final List<Widget> status;

  /// Actions under the text.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        leading,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.titleMediumEmphasized),
                  ?info,
                  ?badge,
                ],
              ),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
              ],
              if (status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: status),
              ],
              if (footer case final footer?) ...[const SizedBox(height: 16), footer],
            ],
          ),
        ),
      ],
    );
  }
}
