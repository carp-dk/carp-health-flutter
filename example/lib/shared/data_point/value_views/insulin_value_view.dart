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
      children: [
        DetailField(label: 'Amount', value: '${formatNumber(value.units)} IU'),
        DetailField(label: 'Reason', value: reasonOf(value.reason)),
      ],
    );
  }

  /// The name of [reason]; the section's info explains them.
  static String reasonOf(InsulinDeliveryReason reason) => switch (reason) {
    InsulinDeliveryReason.BASAL => 'Basal',
    InsulinDeliveryReason.BOLUS => 'Bolus',
    InsulinDeliveryReason.NOT_SET => 'Not set',
  };
}
