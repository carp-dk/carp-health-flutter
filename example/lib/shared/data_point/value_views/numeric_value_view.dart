/// The details of a plain number: what the plugin returned, before the app formatted it.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/format/value_summaries.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// The raw [NumericHealthValue] of [point]: the number and unit the plugin returned, and what the
/// app reads from them (a duration, a coded meaning, a percentage).
class NumericValueView extends StatelessWidget {
  /// Creates the view of [value], the value of [point].
  const NumericValueView({super.key, required this.point, required this.value});

  /// The data point.
  final HealthDataPoint point;

  /// Its value.
  final NumericHealthValue value;

  @override
  Widget build(BuildContext context) {
    final number = value.numericValue;
    final symbol = formatUnit(point.unit);
    final meaning = describeCodedValue(point.type, number);
    return DetailSection(
      title: 'Measurement',
      children: [
        DetailField(label: 'Value', value: '$number', monospace: true),
        DetailField(label: 'Unit', value: symbol.isEmpty ? point.unit.name : '$symbol (${point.unit.name})'),
        if (meaning != null) DetailField(label: 'Meaning', value: meaning),
        // Sleep stages, mindfulness sessions and headaches are categories in Health Connect and
        // HealthKit: the plugin reports them as their length in minutes.
        if (point.unit == HealthDataUnit.MINUTE)
          DetailField(label: 'Duration', value: formatDuration(minutesToDuration(number))),
        // HealthKit measures percentages as fractions, Health Connect from 0 to 100.
        if (point.unit == HealthDataUnit.PERCENT && point.sourcePlatform == HealthPlatformType.appleHealth)
          DetailField(label: 'Percentage', value: '${formatNumber(number * 100, maxDecimals: 1)}%'),
      ],
    );
  }
}
