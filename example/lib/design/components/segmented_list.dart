/// The Material 3 Expressive segmented list: a group of list items drawn as separate rounded segments.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_shapes.dart';

/// A group of list items (usually `ListTile`s), each on its own segment, [gap] apart: the group's ends
/// have large corners ([outerRadius]) and the corners between items small ones ([innerRadius]), so the
/// group reads as one rounded block.
///
/// Each segment clips its item and shapes its ink to match, so tapping an item highlights exactly its
/// segment. Shown as a column: put it in a `SliverToBoxAdapter` or a scrolling parent.
class SegmentedList extends StatelessWidget {
  /// Creates a segmented list of [children].
  const SegmentedList({super.key, required this.children, this.color, this.gap = 2});

  /// The items, top to bottom.
  final List<Widget> children;

  /// The colour of the segments; the surface container colour by default.
  final Color? color;

  /// The space between segments.
  final double gap;

  /// The radius of the group's top and bottom corners.
  static const double outerRadius = ExpressiveShapes.largeIncreased;

  /// The radius of the corners between two items.
  static const double innerRadius = ExpressiveShapes.extraSmall;

  /// The corners of item [index] of [count] items.
  static BorderRadius radiusOf(int index, int count) => BorderRadius.vertical(
    top: Radius.circular(index == 0 ? outerRadius : innerRadius),
    bottom: Radius.circular(index == count - 1 ? outerRadius : innerRadius),
  );

  @override
  Widget build(BuildContext context) {
    final background = color ?? Theme.of(context).colorScheme.surfaceContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (var i = 0; i < children.length; i++)
          _segment(RoundedRectangleBorder(borderRadius: radiusOf(i, children.length)), background, children[i]),
      ],
    );
  }

  Widget _segment(ShapeBorder shape, Color background, Widget child) => Material(
    color: background,
    shape: shape,
    clipBehavior: Clip.antiAlias,
    // List tiles draw their ink in their own shape: give them the segment's.
    child: ListTileTheme.merge(shape: shape, child: child),
  );
}
