/// The details of a period of activity intensity.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_summaries.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// An [ActivityIntensityHealthValue] (Android, where Health Connect has the activity intensity
/// feature), as `writeActivityIntensity` writes it: moderate or vigorous, and for how long.
class ActivityIntensityValueView extends StatelessWidget {
  /// Creates the view of [value].
  const ActivityIntensityValueView({super.key, required this.value});

  /// The period of activity.
  final ActivityIntensityHealthValue value;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Activity intensity',
      children: [
        DetailField(label: 'Intensity', value: formatEnumName(value.intensityLevel)),
        DetailField(label: 'Duration', value: formatDuration(minutesToDuration(value.minutes))),
      ],
    );
  }
}
