/// The interval selected in the Insights chart: when it was, its value, and whose data it holds.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import '../model/interval_series.dart';

/// The details of [bucket], one interval of [series]: its time range, its value and the apps (on iOS
/// also devices) whose data it combines, from the point's `sourceName`.
///
/// [onOpen] opens the interval's data point in the data point sheet; [onClose] clears the selection.
/// An interval without data, which `getHealthIntervalDataFromTypes` leaves out, shows "No data".
class BucketDetails extends StatelessWidget {
  /// Creates the details of [bucket] of [series].
  const BucketDetails({
    super.key,
    required this.series,
    required this.bucket,
    required this.onOpen,
    required this.onClose,
  });

  /// The read the interval belongs to.
  final IntervalSeries series;

  /// The selected interval.
  final IntervalBucket bucket;

  /// Opens the interval's data point.
  final VoidCallback onOpen;

  /// Clears the selection.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = bucket.value;
    return Material(
      color: scheme.tertiaryContainer,
      shape: ExpressiveShapes.rounded(ExpressiveShapes.largeIncreased),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onTertiaryContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      series.describe(bucket),
                      style: theme.textTheme.labelLarge!.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear the selection',
                    onPressed: onClose,
                    icon: Icon(Icons.close, color: scheme.onTertiaryContainer),
                  ),
                ],
              ),
              Text(
                value == null ? 'No data' : series.format(value),
                style: theme.textTheme.headlineSmallEmphasized.tabular.copyWith(color: scheme.onTertiaryContainer),
              ),
              if (value != null) ...[
                if (bucket.sources.isNotEmpty) ...[const SizedBox(height: 8), _Sources(sources: bucket.sources)],
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: scheme.onTertiaryContainer),
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('Inspect'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The sources of an interval as small outlined pills, or a note that the platform named none.
class _Sources extends StatelessWidget {
  const _Sources({required this.sources});

  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onTertiaryContainer;
    if (sources.isEmpty) {
      return Text('No source named', style: theme.textTheme.bodySmall!.copyWith(color: color));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final source in sources)
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.4))),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Icon(Icons.apps, size: 14, color: color),
                  Flexible(
                    child: Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium!.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
