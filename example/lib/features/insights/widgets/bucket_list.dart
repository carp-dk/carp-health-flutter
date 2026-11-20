/// The intervals of an Insights read that had data, as a list: the value, time and sources of each.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import '../model/interval_series.dart';

/// The intervals of [series] that had data, newest first, in a `SegmentedList`: each with a small bar of
/// its value against the largest, its value, when it was and the apps whose data it combines (the
/// point's `sourceName`, which names them all, joined by ", "). The [selected] interval is highlighted
/// in the tertiary colours of the chart's selected bar; tapping an interval calls [onTap].
class BucketList extends StatelessWidget {
  /// Creates the list of [series]' intervals with data.
  const BucketList({super.key, required this.series, this.selected, required this.onTap});

  /// The read whose intervals to list.
  final IntervalSeries series;

  /// The index of the selected interval, or null.
  final int? selected;

  /// Called with the interval the user tapped.
  final ValueChanged<IntervalBucket> onTap;

  @override
  Widget build(BuildContext context) {
    final buckets = series.withData.reversed.toList();
    if (buckets.isEmpty) {
      return const EmptyState(icon: Icons.bar_chart, shape: ExpressiveShape.cookie12, title: 'No data');
    }
    final largest = buckets.fold<num>(0, (largest, bucket) => math.max(largest, bucket.value!.abs()));
    return SegmentedList(
      children: [
        for (final bucket in buckets)
          _BucketTile(
            series: series,
            bucket: bucket,
            share: largest == 0 ? 0 : bucket.value!.abs() / largest,
            selected: bucket.index == selected,
            onTap: () => onTap(bucket),
          ),
      ],
    );
  }
}

/// One interval: its share of the largest value as a bar, the value, the time and the sources.
class _BucketTile extends StatelessWidget {
  const _BucketTile({
    required this.series,
    required this.bucket,
    required this.share,
    required this.selected,
    required this.onTap,
  });

  final IntervalSeries series;
  final IntervalBucket bucket;
  final double share;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sources = bucket.sources;
    return ListTile(
      selected: selected,
      // The chart shows its selected bar in tertiary: the list matches it.
      selectedTileColor: scheme.tertiaryContainer,
      selectedColor: scheme.onTertiaryContainer,
      onTap: onTap,
      leading: _ShareBar(share: share, color: selected ? scheme.tertiary : scheme.primary),
      // As the tile's title style, so that the tile's selected colour still applies to it.
      titleTextStyle: theme.textTheme.titleMediumEmphasized.tabular,
      title: Text(series.format(bucket.value!)),
      subtitle: Text(
        sources.isEmpty ? series.describe(bucket) : '${series.describe(bucket)}\n${sources.join(', ')}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: sources.isNotEmpty,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// A short vertical track with a rounded bar filled to [share] (0 to 1): a bar of the chart in small.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share, required this.color});

  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const motion = ExpressiveMotion.spatialDefault;
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Container(
          width: 12,
          decoration: ShapeDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: ExpressiveShapes.stadium,
          ),
          alignment: Alignment.bottomCenter,
          // A sliver stays for the smallest values, so every listed interval shows a bar.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: share.clamp(0.12, 1.0)),
            duration: motion.duration,
            curve: motion,
            builder: (context, fill, _) => FractionallySizedBox(
              heightFactor: fill.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: ShapeDecoration(color: color, shape: ExpressiveShapes.stadium),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
