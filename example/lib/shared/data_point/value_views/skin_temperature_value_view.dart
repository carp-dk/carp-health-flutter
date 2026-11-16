/// The details of a skin temperature measurement.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// A [SkinTemperatureHealthValue] (Android, where Health Connect has the skin temperature feature):
/// the change from the user's baseline, the baseline when known, the temperature that gives, and
/// where it was measured.
class SkinTemperatureValueView extends StatelessWidget {
  /// Creates the view of [value].
  const SkinTemperatureValueView({super.key, required this.value});

  /// The measurement.
  final SkinTemperatureHealthValue value;

  @override
  Widget build(BuildContext context) {
    final delta = value.temperatureDelta;
    return DetailSection(
      title: 'Skin temperature',
      subtitle: 'SkinTemperatureHealthValue (Android)',
      children: [
        DetailField(label: 'Change from baseline', value: '${delta >= 0 ? '+' : ''}${formatNumber(delta)} °C'),
        DetailField(
          label: 'Baseline',
          value: value.baseline == null ? 'Not recorded' : '${formatNumber(value.baseline!)} °C',
        ),
        // SkinTemperatureHealthValue.temperature is the baseline plus the change, when there is a baseline.
        if (value.temperature case final temperature?)
          DetailField(label: 'Temperature', value: '${formatNumber(temperature)} °C'),
        DetailField(label: 'Measured at', value: formatEnumName(value.measurementLocation)),
      ],
    );
  }
}
