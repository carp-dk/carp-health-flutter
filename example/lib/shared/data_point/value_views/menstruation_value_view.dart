/// The details of a menstrual flow entry.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// A [MenstruationFlowHealthValue], as `writeMenstruationFlow` writes it: the flow, whether the day
/// starts a cycle and whether the user entered it (both recorded by HealthKit only), and its date.
class MenstruationValueView extends StatelessWidget {
  /// Creates the view of [value].
  const MenstruationValueView({super.key, required this.value});

  /// The flow entry.
  final MenstruationFlowHealthValue value;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Menstrual flow',
      subtitle: 'MenstruationFlowHealthValue',
      children: [
        DetailField(label: 'Flow', value: value.flow == null ? 'Not recorded' : formatEnumName(value.flow!)),
        DetailField(label: 'Start of cycle', value: _yesNo(value.isStartOfCycle)),
        DetailField(label: 'Entered by the user', value: _yesNo(value.wasUserEntered)),
        DetailField(label: 'Date', value: formatDateTime(value.dateTime)),
      ],
    );
  }

  /// Yes or no; Health Connect records neither of the flags, which then read as null.
  static String _yesNo(bool? flag) => switch (flag) {
    true => 'Yes',
    false => 'No',
    null => 'Not recorded (HealthKit only)',
  };
}
