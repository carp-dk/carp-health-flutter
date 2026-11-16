/// Two blocks of a form side by side on wide windows and stacked on phones.
library;

import 'package:flutter/material.dart';

/// Lays out [first] and [second] side by side, equally wide, when there is at least [breakpoint] of width,
/// and one under the other otherwise, so the Read page's forms use the width of a tablet.
class AdaptivePair extends StatelessWidget {
  /// Creates the pair.
  const AdaptivePair({super.key, required this.first, required this.second, this.spacing = 16, this.breakpoint = 720});

  /// The block at the start (or on top).
  final Widget first;

  /// The block at the end (or below).
  final Widget second;

  /// The space between the blocks.
  final double spacing;

  /// The narrowest width at which the blocks go side by side.
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing,
            children: [first, second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing,
          children: [
            Expanded(child: first),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
