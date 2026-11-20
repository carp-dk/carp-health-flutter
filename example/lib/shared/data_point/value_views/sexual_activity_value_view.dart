/// The details of a sexual activity entry.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// A [SexualActivityHealthValue], as `writeSexualActivity` writes it: whether protection was used.
class SexualActivityValueView extends StatelessWidget {
  /// Creates the view of [value].
  const SexualActivityValueView({super.key, required this.value});

  /// The sexual activity entry.
  final SexualActivityHealthValue value;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Sexual activity',
      children: [DetailField(label: 'Protection', value: _protectionLabel(value.protectionUsed))],
    );
  }

  static String _protectionLabel(SexualActivityProtection protection) => switch (protection) {
    SexualActivityProtection.protected => 'Protected',
    SexualActivityProtection.unprotected => 'Unprotected',
    SexualActivityProtection.unknown => 'Unspecified',
  };
}
