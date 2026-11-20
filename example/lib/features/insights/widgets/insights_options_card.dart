/// The options of an Insights read: the data type, the interval length, the range and the manual entry
/// filter.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

import '../insights_controller.dart';
import '../model/insights_options.dart';

/// Compact interval, range, and manual-entry filter controls for [controller].
class InsightsOptionsCard extends StatelessWidget {
  /// Creates the options of [controller]'s read.
  const InsightsOptionsCard({super.key, required this.controller});

  /// The Insights state, which reads again when an option changes.
  final InsightsController controller;

  @override
  Widget build(BuildContext context) {
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          ConnectedButtonGroup<InsightsInterval>(
            segments: [
              for (final interval in InsightsInterval.values)
                ButtonGroupSegment(value: interval, label: interval.label, icon: interval.icon),
            ],
            selected: controller.interval,
            onSelected: controller.selectInterval,
          ),
          ConnectedButtonGroup<InsightsRange>(
            segments: [for (final range in InsightsRange.values) ButtonGroupSegment(value: range, label: range.label)],
            selected: controller.range,
            onSelected: controller.selectRange,
          ),
          if (controller.type != null) _ManualFilter(controller: controller),
        ],
      ),
    );
  }
}

/// "Exclude manual": `recordingMethodsToFilter: [RecordingMethod.manual]`.
class _ManualFilter extends StatelessWidget {
  const _ManualFilter({required this.controller});

  final InsightsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ignored = !controller.manualFilterApplies && controller.platform == HealthPlatformType.googleHealthConnect;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: controller.excludeManual,
      onChanged: controller.setExcludeManual,
      title: Text('Exclude manual', style: theme.textTheme.titleSmallEmphasized),
      subtitle: ignored ? const Text('Not applied to this type') : null,
    );
  }
}
