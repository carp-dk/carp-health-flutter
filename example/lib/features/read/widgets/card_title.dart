/// The title row of the Read page's cards.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// A card's title: an [icon] in an expressive [shape], an emphasized [title], an optional [subtitle] (usually
/// the plugin method the card is about) and an optional [trailing] widget, such as a `PlatformBadge`.
class CardTitle extends StatelessWidget {
  /// Creates a card title.
  const CardTitle({
    super.key,
    required this.icon,
    required this.title,
    this.shape = ExpressiveShape.cookie9,
    this.subtitle,
    this.trailing,
  });

  /// The icon in the shape.
  final IconData icon;

  /// The card's name.
  final String title;

  /// The shape behind the icon.
  final ExpressiveShape shape;

  /// A line under the title.
  final String? subtitle;

  /// A widget at the end, such as a badge or a count.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 12,
      children: [
        ShapedIcon(icon: icon, shape: shape, size: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMediumEmphasized),
              if (subtitle case final subtitle?)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
