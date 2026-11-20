/// The title row of the Read page's cards.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// A card's title: an [icon] in an expressive [shape], an emphasized [title] with an [InfoButton] when there
/// is an [info] or [code] to show, and an optional [trailing] widget, such as a status pill.
class CardTitle extends StatelessWidget {
  /// Creates a card title.
  const CardTitle({
    super.key,
    required this.icon,
    required this.title,
    this.shape = ExpressiveShape.cookie9,
    this.info,
    this.code,
    this.trailing,
  });

  /// The icon in the shape.
  final IconData icon;

  /// The card's name.
  final String title;

  /// The shape behind the icon.
  final ExpressiveShape shape;

  /// What the card does and how the plugin behaves, opened from the info button.
  final String? info;

  /// The plugin call the card makes, shown in monospace in the info sheet.
  final String? code;

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
          child: Row(
            spacing: 4,
            children: [
              Flexible(child: Text(title, style: theme.textTheme.titleMediumEmphasized)),
              if (info != null || code != null) InfoButton(title: title, message: info, code: code),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
