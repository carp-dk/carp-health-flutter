/// The Insights chart card: what was read, a few figures of the read, the bar chart and the selected
/// interval.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/type_icon.dart';
import 'package:health_example/shared/widgets/async_value_view.dart';
import 'package:health_example/shared/widgets/type_picker_sheet.dart';

import '../insights_controller.dart';
import '../model/interval_series.dart';
import 'bucket_details.dart';
import 'interval_bar_chart.dart';

/// The hero chart card for [controller]'s interval read (`getHealthIntervalDataFromTypes`), with an
/// interactive type selector in its header, summary figures, bar chart, and selected [BucketDetails].
class IntervalChartCard extends StatelessWidget {
  /// Creates the chart card of [controller]'s read.
  const IntervalChartCard({super.key, required this.controller, required this.onOpenBucket});

  /// The Insights state: the read, its options and the selection.
  final InsightsController controller;

  /// Opens the data point of an interval.
  final ValueChanged<IntervalBucket> onOpenBucket;

  Future<void> _pickType(BuildContext context) async {
    final type = controller.type;
    final picked = await showTypePicker(
      context,
      available: controller.types,
      initial: {?type},
      multiple: false,
      title: 'Choose data type',
    );
    if (picked == null || picked.isEmpty) return;
    await controller.selectType(picked.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = controller.type;
    if (type == null) return const SizedBox.shrink();
    return ExpressiveCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 14,
            children: [
              TypeIcon(type: type, size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: theme.textTheme.titleLargeEmphasized),
                    Text(
                      '${controller.interval.label} · ${controller.range.label}',
                      style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Change type',
                onPressed: () => _pickType(context),
                icon: const Icon(Icons.swap_horiz),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AsyncValueView(
            value: controller.series,
            onRetry: controller.loadSeries,
            loadingLabel: 'Reading ${type.label}…',
            data: (context, series) => _ChartBody(controller: controller, series: series, onOpenBucket: onOpenBucket),
          ),
        ],
      ),
    );
  }
}

/// The figures, the chart and the selected interval.
class _ChartBody extends StatelessWidget {
  const _ChartBody({required this.controller, required this.series, required this.onOpenBucket});

  final InsightsController controller;
  final IntervalSeries series;
  final ValueChanged<IntervalBucket> onOpenBucket;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedBucket;
    const motion = ExpressiveMotion.spatialDefault;
    final peak = series.peak;
    final mean = series.mean;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            _Figure(label: 'Peak', value: peak == null ? '—' : series.format(peak.value!)),
            _Figure(label: 'Avg', value: mean == null ? '—' : series.format(mean, rounded: true)),
            _Figure(
              label: 'Active',
              value: '${formatNumber(series.withData.length)} / ${formatNumber(series.buckets.length)}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        IntervalBarChart(series: series, selected: controller.selected, onSelected: controller.toggle),
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: selected == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: BucketDetails(
                    series: series,
                    bucket: selected,
                    onOpen: () => onOpenBucket(selected),
                    onClose: () => controller.select(null),
                  ),
                ),
        ),
      ],
    );
  }
}

/// One figure of the read: a label over an emphasized value, a third of the row.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, maxLines: 1, style: theme.textTheme.titleLargeEmphasized.tabular),
          ),
        ],
      ),
    );
  }
}
