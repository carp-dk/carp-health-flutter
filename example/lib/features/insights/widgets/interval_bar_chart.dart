/// The Insights bar chart: a rounded bar per interval of a `getHealthIntervalDataFromTypes` read,
/// growing in on a spring, with value gridlines and time labels. Tapping a bar selects its interval.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';

import '../model/chart_axis.dart';
import '../model/insights_options.dart';
import '../model/interval_series.dart';
import 'interval_bar_painter.dart';

/// A bar chart of [series]: one bar per interval, intervals without data as bare tracks.
///
/// The bars grow in one after another on the slow spatial spring whenever a new series arrives (at once
/// when the platform asks to reduce motion). Tapping reports the interval under the finger through
/// [onSelected] (null beside the bars); the [selected] bar turns tertiary and pops its value up in a
/// callout. The intervals are labelled by the length the series was read with, so a read that is still
/// shown while the next one loads keeps its own labels.
class IntervalBarChart extends StatefulWidget {
  /// Creates the chart of [series] with bucket [selected] (or none) selected.
  const IntervalBarChart({
    super.key,
    required this.series,
    required this.selected,
    required this.onSelected,
    this.height = 240,
  });

  /// The read to show.
  final IntervalSeries series;

  /// The index of the selected bucket, or null.
  final int? selected;

  /// Called with the index of the tapped bucket, or null for a tap beside the bars.
  final ValueChanged<int?> onSelected;

  /// The height of the chart, labels included.
  final double height;

  @override
  State<IntervalBarChart> createState() => _IntervalBarChartState();
}

class _IntervalBarChartState extends State<IntervalBarChart> with TickerProviderStateMixin {
  // Linear: the painter puts each bar on the spring itself, staggered from the left.
  late final AnimationController _grow = AnimationController(vsync: this, duration: IntervalBarPainter.growDuration);

  // At rest (1) the selected bar is fully emphasized; a new selection plays it from 0.
  late final AnimationController _selection = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.spatialFast.duration,
    value: 1,
  );

  late _ChartData _data = _ChartData.of(widget.series);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first grow-in waits for here, where the motion setting of the platform can be read.
    if (!_started) {
      _started = true;
      _play(_grow);
    }
  }

  @override
  void didUpdateWidget(IntervalBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.series, widget.series)) {
      _data = _ChartData.of(widget.series);
      _play(_grow);
    }
    if (oldWidget.selected != widget.selected && widget.selected != null) _play(_selection);
  }

  @override
  void dispose() {
    _grow.dispose();
    _selection.dispose();
    super.dispose();
  }

  /// Runs [controller] from 0 to 1, or jumps to 1 when the platform asks to reduce motion.
  void _play(AnimationController controller) {
    if (ExpressiveMotion.isReduced(context)) {
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    final buckets = widget.series.buckets;
    final index = widget.selected;
    final bucket = index == null || index >= buckets.length ? null : buckets[index];
    // Screen readers get a summary here; the list of intervals under the chart reads out each one.
    return Semantics(
      label: data.description,
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, widget.height);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    widget.onSelected(BarChartGeometry.indexAt(details.localPosition, size, buckets.length)),
                child: CustomPaint(
                  size: size,
                  painter: IntervalBarPainter(
                    values: data.values,
                    axis: data.axis,
                    labels: data.labels,
                    interval: data.interval,
                    selected: bucket?.index,
                    calloutText: bucket == null ? null : data.calloutOf(bucket),
                    grow: _grow,
                    selection: _selection,
                    colors: BarChartColors.of(theme.colorScheme),
                    labelStyle: theme.textTheme.labelSmall!,
                    calloutStyle: theme.textTheme.labelLargeEmphasized,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What the painter draws for one series, worked out once per series rather than on every frame.
class _ChartData {
  _ChartData._(this.series, this.interval, this.values, this.axis, this.labels);

  factory _ChartData.of(IntervalSeries series) {
    final interval = series.interval;
    final values = List<double?>.unmodifiable([
      for (final bucket in series.buckets)
        if (bucket.value case final value?) series.chartValue(value) else null,
    ]);
    final present = values.nonNulls;
    final axis = ChartAxis.fit(
      min: present.fold<double>(0, math.min),
      max: present.fold<double>(0, math.max),
      unit: series.unit,
    );
    final count = series.buckets.length;
    final labels = List<String>.unmodifiable([
      for (final bucket in series.buckets) interval.axisLabel(bucket.start, count),
    ]);
    return _ChartData._(series, interval, values, axis, labels);
  }

  final IntervalSeries series;
  final InsightsInterval interval;
  final List<double?> values;
  final ChartAxis axis;
  final List<String> labels;

  /// The callout of [bucket]: its value with unit and its time label, such as "1,234 · Mon".
  String calloutOf(IntervalBucket bucket) {
    final value = bucket.value;
    return '${value == null ? 'No data' : series.format(value)} · ${labels[bucket.index]}';
  }

  /// A summary of the chart for screen readers.
  String get description {
    final withData = series.withData.length;
    final peak = series.peak;
    final peakText = peak == null ? '' : ' The peak is ${series.format(peak.value!)} at ${labels[peak.index]}.';
    return 'Bar chart of ${series.type.label} per ${interval.label.toLowerCase()}: '
        '${formatNumber(withData)} of ${formatNumber(series.buckets.length)} intervals have data.$peakText';
  }
}
