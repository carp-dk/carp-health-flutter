/// The details of an insulin delivery.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// An [InsulinDeliveryHealthValue] (iOS), as `writeInsulinDelivery` writes it: the units of insulin
/// and why they were delivered.
class InsulinValueView extends StatelessWidget {
  /// Creates the view of [value].
  const InsulinValueView({super.key, required this.value});

  /// The delivery.
  final InsulinDeliveryHealthValue value;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Insulin delivery',
      subtitle: 'InsulinDeliveryHealthValue (iOS)',
      children: [
        DetailField(label: 'Amount', value: '${formatNumber(value.units)} IU'),
        DetailField(label: 'Reason', value: reasonOf(value.reason)),
      ],
    );
  }

  /// What [reason] means.
  static String reasonOf(InsulinDeliveryReason reason) => switch (reason) {
    InsulinDeliveryReason.BASAL => 'Basal: the steady background dose',
    InsulinDeliveryReason.BOLUS => 'Bolus: a dose for a meal or a correction',
    InsulinDeliveryReason.NOT_SET => 'Not set',
  };
}
