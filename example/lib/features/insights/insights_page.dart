/// Insights: health data summed or averaged over intervals.
///
/// Demonstrates `Health.getHealthIntervalDataFromTypes` for one type at a time (the interval types of
/// the `TypeCatalog`), in intervals of an hour, a day or a week over today, 7 or 30 days, optionally
/// leaving out manual entries (`recordingMethodsToFilter`), shown as an animated bar chart and a list of
/// the intervals with their sources. Next to it, `Health.getTotalStepsInInterval` counts the steps over
/// the same range, with or without manual entries (`includeManualEntry`). [InsightsController] makes the
/// calls.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/widgets/health_connect_banner.dart';

import 'insights_controller.dart';
import 'model/interval_series.dart';
import 'widgets/bucket_list.dart';
import 'widgets/insights_options_card.dart';
import 'widgets/interval_chart_card.dart';
import 'widgets/steps_total_card.dart';

/// The Insights destination: the read's options, the chart, the step total, the note on Health Connect's
/// priority list and the list of intervals, with pull to refresh. From [wideLayout] on, the step total
/// and the note sit beside the options.
class InsightsPage extends StatefulWidget {
  /// Creates the Insights page.
  const InsightsPage({super.key});

  /// The content width from which cards sit side by side.
  static const double wideLayout = 720;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

/// Owns the [InsightsController], created from the app's services and disposed with the page.
class _InsightsPageState extends State<InsightsPage> {
  late final AppServices _services;
  late final InsightsController _controller;

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be called here.
    _services = AppScope.of(context);
    _controller = InsightsController(health: _services.health, catalog: _services.catalog)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Selects [bucket] in the chart and opens its data point: the aggregate the plugin returned, which
  /// has no UUID, as it is not a record.
  void _openBucket(IntervalBucket bucket) {
    _controller.select(bucket.index);
    final point = bucket.point;
    if (point != null) showDataPointSheet(context, point);
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = _services.capabilities;
    return ListenableBuilder(
      // The catalog's interval types follow the capabilities, which another page may refresh.
      listenable: Listenable.merge([_controller, capabilities]),
      builder: (context, _) => ExpressivePage(
        title: 'Insights',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _controller.load, icon: const Icon(Icons.refresh))],
        onRefresh: _controller.load,
        slivers: [
          SliverToBoxAdapter(
            child: HealthConnectBanner(capabilities: capabilities, padding: const EdgeInsets.only(bottom: 16)),
          ),
          if (_controller.type == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.query_stats, title: 'No interval types'),
            )
          else
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: constraints.maxWidth >= InsightsPage.wideLayout ? _wide() : _compact(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Phones: chart hero first, then controls, steps total, and interval list.
  List<Widget> _compact() => [
    IntervalChartCard(controller: _controller, onOpenBucket: _openBucket),
    const SizedBox(height: 16),
    InsightsOptionsCard(controller: _controller),
    const SizedBox(height: 16),
    StepsTotalCard(controller: _controller),
    ..._intervals(),
  ];

  /// Tablets: controls beside the step total, then the chart and intervals across.
  List<Widget> _wide() => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Expanded(flex: 3, child: InsightsOptionsCard(controller: _controller)),
        Expanded(flex: 2, child: StepsTotalCard(controller: _controller)),
      ],
    ),
    const SizedBox(height: 16),
    IntervalChartCard(controller: _controller, onOpenBucket: _openBucket),
    ..._intervals(),
  ];

  /// The header and list of the intervals with data, once a read is in.
  List<Widget> _intervals() {
    final series = _controller.series.valueOrNull;
    if (series == null) return const [];
    return [
      const SectionHeader(title: 'Intervals'),
      BucketList(series: series, selected: _controller.selected, onTap: _openBucket),
    ];
  }
}
