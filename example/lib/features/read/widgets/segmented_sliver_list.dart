/// A segmented list that builds its items lazily, for the long lists of the Read page.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// The Material 3 Expressive segmented list of `SegmentedList` as a sliver that builds only the items on
/// screen, so that a result of thousands of data points scrolls smoothly.
///
/// Items (usually `ListTile`s) sit on segments [gap] apart, with large corners at the ends of the list and
/// small ones between items (`SegmentedList.radiusOf`); each segment shapes its item's ink to match.
class SegmentedSliverList extends StatelessWidget {
  /// Creates a lazily built segmented list of [itemCount] items built by [itemBuilder].
  const SegmentedSliverList({super.key, required this.itemCount, required this.itemBuilder, this.color, this.gap = 2});

  /// How many items the list has.
  final int itemCount;

  /// Builds the item at an index, when it scrolls into view.
  final IndexedWidgetBuilder itemBuilder;

  /// The colour of the segments; the surface container colour by default, as for `SegmentedList`.
  final Color? color;

  /// The space between segments.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final background = color ?? Theme.of(context).colorScheme.surfaceContainer;
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final shape = RoundedRectangleBorder(borderRadius: SegmentedList.radiusOf(index, itemCount));
        return Padding(
          padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : gap),
          child: Material(
            color: background,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            // List tiles draw their ink in their own shape: give them the segment's.
            child: ListTileTheme.merge(shape: shape, child: itemBuilder(context, index)),
          ),
        );
      },
    );
  }
}
