/// The heading of a Setup card: its icon, its name and the explanation on demand.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// A shaped [icon] beside the [title], followed by an optional [info] button (usually an `InfoButton`
/// with the plugin call behind the card) and an optional platform [badge].
class CardHeading extends StatelessWidget {
  /// Creates a heading.
  const CardHeading({super.key, required this.icon, required this.title, this.info, this.badge});

  /// The icon at the start, usually a `ShapedIcon`.
  final Widget icon;

  /// The card's name.
  final String title;

  /// The explanation on demand, next to the title.
  final Widget? info;

  /// A `PlatformBadge`, for something one platform has.
  final Widget? badge;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 16,
    children: [
      icon,
      Expanded(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMediumEmphasized),
            ?info,
            ?badge,
          ],
        ),
      ),
    ],
  );
}
