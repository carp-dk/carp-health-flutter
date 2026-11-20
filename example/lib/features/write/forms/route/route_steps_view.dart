/// The plugin calls of the last workout route write or discard, with what each returned.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';

import 'route_step.dart';

/// [steps] as a segmented list: each call's method, a shape that morphs with its status (a loading
/// indicator while it runs), and what it returned or why it failed. Nothing before the first run.
class RouteStepsView extends StatelessWidget {
  /// Creates the list of [steps].
  const RouteStepsView({super.key, required this.steps});

  /// The calls, in order.
  final List<RouteStep> steps;

  @override
  Widget build(BuildContext context) {
    const motion = ExpressiveMotion.spatialDefault;
    return AnimatedSize(
      duration: motion.duration,
      curve: motion,
      alignment: Alignment.topCenter,
      child: steps.isEmpty
          ? const SizedBox(width: double.infinity)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Calls'),
                SegmentedList(children: [for (final step in steps) _StepTile(step: step)]),
              ],
            ),
    );
  }
}

/// One call and its status.
class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});

  final RouteStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ExpressiveStatusColors.of(context);
    final (IconData icon, ExpressiveShape shape, Color background, Color foreground) = switch (step.status) {
      RouteStepStatus.pending => (
        Icons.more_horiz,
        ExpressiveShape.circle,
        scheme.surfaceContainerHighest,
        scheme.outline,
      ),
      RouteStepStatus.running => (
        Icons.sync,
        ExpressiveShape.circle,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      RouteStepStatus.done => (Icons.check, ExpressiveShape.cookie9, status.success, status.onSuccess),
      RouteStepStatus.failed => (Icons.close, ExpressiveShape.puffy, status.error, status.onError),
    };
    final detail = switch (step.status) {
      RouteStepStatus.pending => 'Not called',
      RouteStepStatus.running => 'Running…',
      RouteStepStatus.done => 'Returned ${step.detail}',
      RouteStepStatus.failed => step.detail ?? 'Failed',
    };
    return ListTile(
      leading: SizedBox.square(
        dimension: 40,
        child: step.status == RouteStepStatus.running
            ? ExpressiveLoadingIndicator(size: 40, contained: true, semanticsLabel: 'Calling ${step.method}')
            : ShapedIcon(icon: icon, shape: shape, size: 40, background: background, foreground: foreground),
      ),
      title: Text(step.method, style: theme.textTheme.titleSmall!.monospace),
      subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
