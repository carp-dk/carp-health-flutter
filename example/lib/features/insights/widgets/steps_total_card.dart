/// The step total over the Insights range: `getTotalStepsInInterval`, with or without manual entries.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/async_value_view.dart';

import '../insights_controller.dart';
import '../model/steps_total.dart';

/// A vibrant card with the steps `getTotalStepsInInterval` counts over [controller]'s range, and a
/// switch for `includeManualEntry`.
class StepsTotalCard extends StatelessWidget {
  /// Creates the card of [controller]'s step total.
  const StepsTotalCard({super.key, required this.controller});

  /// The Insights state: the step total and its options.
  final InsightsController controller;

  @override
  Widget build(BuildContext context) {
    return ExpressiveCard(
      variant: ExpressiveCardVariant.vibrant,
      // Built below the card, so that the theme's text styles carry the card's content colour.
      child: Builder(builder: _content),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 14,
          children: [
            ShapedIcon(
              icon: Icons.directions_walk,
              shape: ExpressiveShape.sunny,
              background: scheme.primary,
              foreground: scheme.onPrimary,
            ),
            Flexible(child: Text('Steps', style: theme.textTheme.titleLargeEmphasized)),
          ],
        ),
        const SizedBox(height: 12),
        AsyncValueView<StepsTotal>(
          value: controller.steps,
          onRetry: controller.loadSteps,
          loadingLabel: 'Counting steps…',
          data: (context, total) => _Total(total: total),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: controller.includeManualSteps,
          onChanged: controller.setIncludeManualSteps,
          title: Text('Include manual', style: theme.textTheme.titleSmallEmphasized),
        ),
      ],
    );
  }
}

/// The total: a big emphasized number and the range it covers.
class _Total extends StatelessWidget {
  const _Total({required this.total});

  final StepsTotal total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(
              text: formatNumber(total.steps),
              style: theme.textTheme.displaySmallEmphasized.tabular,
              children: [TextSpan(text: ' steps', style: theme.textTheme.titleMedium)],
            ),
          ),
        ),
        Text(formatTimeRange(total.range.start, total.range.end), style: theme.textTheme.bodySmall),
      ],
    );
  }
}
