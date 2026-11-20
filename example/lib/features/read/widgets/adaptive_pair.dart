/// Two blocks of a form side by side on wide windows and stacked on phones.
library;

import 'package:flutter/material.dart';

/// Lays out [first] and [second] side by side, equally wide, when there is at least [breakpoint] of width,
/// and one under the other otherwise, so the Read page's forms use the width of a tablet.
///
/// With [equalHeight], side-by-side blocks (usually two cards) are stretched to the taller one's height.
/// That measures their intrinsic height, so it must not be used for blocks containing a `LayoutBuilder`.
class AdaptivePair extends StatelessWidget {
  /// Creates the pair.
  const AdaptivePair({
    super.key,
    required this.first,
    required this.second,
    this.spacing = 16,
    this.breakpoint = 720,
    this.equalHeight = false,
  });

  /// The block at the start (or on top).
  final Widget first;

  /// The block at the end (or below).
  final Widget second;

  /// The space between the blocks.
  final double spacing;

  /// The narrowest width at which the blocks go side by side.
  final double breakpoint;

  /// Whether side-by-side blocks take the same height.
  final bool equalHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing, children: [first, second]);
        }
        final row = Row(
          crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          spacing: spacing,
          children: [
            Expanded(child: first),
            Expanded(child: second),
          ],
        );
        return equalHeight ? IntrinsicHeight(child: row) : row;
      },
    );
  }
}
