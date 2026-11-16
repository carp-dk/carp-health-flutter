/// One labelled option of a form card on the Read page.
library;

import 'package:flutter/material.dart';
import 'package:health_example/shared/visuals/monospace.dart';

/// An option: a [label], the control ([child]) and a [caption] under it that explains the option. The
/// [parameter] the option sets on the plugin call, such as `limit`, shows after the label in monospace, so
/// the form doubles as a reference for the API.
class OptionBlock extends StatelessWidget {
  /// Creates an option block.
  const OptionBlock({super.key, required this.label, required this.child, this.parameter, this.caption});

  /// What the option is, such as "Newest points per type".
  final String label;

  /// The plugin parameter or property the option sets, such as `limit` or `Health.pageSize`.
  final String? parameter;

  /// The control.
  final Widget child;

  /// What the option does, in a sentence or two.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge!.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (parameter case final parameter?)
                TextSpan(text: '  $parameter', style: labelStyle.copyWith(color: scheme.primary).monospace),
            ],
          ),
          style: labelStyle,
        ),
        const SizedBox(height: 8),
        child,
        if (caption case final caption?) ...[
          const SizedBox(height: 6),
          Text(caption, style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}
