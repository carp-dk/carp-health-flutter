/// Puts the Setup page's cards side by side where the window is wide enough.
library;

import 'package:flutter/material.dart';

/// Lays [children] out in one column on phones and two columns from [breakpoint] dp of available width
/// (tablets, landscape), top-aligned and [spacing] apart.
class ResponsiveColumns extends StatelessWidget {
  /// Creates the layout of [children].
  const ResponsiveColumns({super.key, required this.children, this.breakpoint = 560, this.spacing = 12});

  /// The widgets, in reading order: left to right, then top to bottom.
  final List<Widget> children;

  /// The width from which two columns are used.
  final double breakpoint;

  /// The space between the children, both ways.
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint || children.length < 2) {
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
