/// The hero card of the Write page: writes the sample data and shows how the run goes.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import 'sample_data_controller.dart';

/// A vibrant card that starts the sample data ([SampleDataController.run]) and stops it, requests write
/// access to its types ([SampleDataController.requestAccess]) and shows the run: a wavy progress bar with
/// the step that is running, then a pill per outcome. What the run writes, with which plugin methods,
/// opens from an `InfoButton`. The per-step list sits under the card.
class SampleDataCard extends StatelessWidget {
  /// Creates the card of [controller].
  const SampleDataCard({
    super.key,
    required this.controller,
    this.showSteps = false,
    this.onToggleSteps,
  });

  /// The sample data's state and calls.
  final SampleDataController controller;

  /// Whether the per-step list below the card is expanded.
  final bool showSteps;

  /// Toggles the per-step list below the card.
  final VoidCallback? onToggleSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = ExpressiveCardVariant.vibrant.foregroundIn(scheme);
    final reduced = ExpressiveMotion.reduceMotion(context);
    final motionDuration = reduced ? Duration.zero : ExpressiveMotion.spatialDefault.duration;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.vibrant,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 14,
            children: [
              ShapedIcon(
                icon: Icons.auto_awesome,
                shape: controller.isRunning ? ExpressiveShape.sunny : ExpressiveShape.softBurst,
                size: 48,
                background: scheme.primary,
                foreground: scheme.onPrimary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // This context is outside the card, whose text colour a theme style would override.
                    Text('Sample data', style: theme.textTheme.titleLargeEmphasized.copyWith(color: foreground)),
                    Text(
                      '${controller.runnableCount} writes',
                      style: theme.textTheme.bodyMedium!.copyWith(color: foreground.withValues(alpha: 0.8)).tabular,
                    ),
                  ],
                ),
              ),
              if (onToggleSteps case final toggle?)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: foreground),
                  onPressed: toggle,
                  icon: AnimatedRotation(
                    turns: showSteps ? 0.5 : 0,
                    duration: motionDuration,
                    curve: ExpressiveMotion.spatialFast,
                    child: const Icon(Icons.expand_more, size: 20),
                  ),
                  label: Text(showSteps ? 'Hide' : 'Steps'),
                ),
            ],
          ),
          AnimatedSize(
            duration: motionDuration,
            curve: ExpressiveMotion.spatialDefault,
            alignment: Alignment.topCenter,
            child: controller.hasRun ? _RunStatus(controller: controller) : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [_runButton(), _accessButton(foreground)]),
          _AccessResult(access: controller.access, onRetry: controller.requestAccess),
        ],
      ),
    );
  }

  /// Write (or write again), or stop while running.
  Widget _runButton() {
    if (controller.isRunning) {
      return FilledButton.tonalIcon(
        onPressed: controller.isCancelling ? null : controller.cancel,
        icon: const Icon(Icons.stop_circle_outlined),
        label: Text(controller.isCancelling ? 'Stopping…' : 'Stop'),
      );
    }
    return FilledButton.icon(
      onPressed: controller.runnableCount == 0 ? null : controller.run,
      icon: Icon(controller.hasRun ? Icons.replay : Icons.play_arrow),
      label: Text(controller.hasRun ? 'Write again' : 'Write sample data'),
    );
  }

  /// `requestAuthorization` for every type the sample data writes.
  Widget _accessButton(Color foreground) {
    final requesting = controller.access.isLoading;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: foreground),
      onPressed: requesting || controller.isRunning ? null : controller.requestAccess,
      icon: requesting
          ? const ExpressiveLoadingIndicator(size: 20, semanticsLabel: 'Requesting access')
          : const Icon(Icons.lock_open),
      label: Text('Access (${controller.accessTypes.length})'),
    );
  }
}

/// The progress of a run and, once it ended, how it went.
class _RunStatus extends StatelessWidget {
  const _RunStatus({required this.controller});

  final SampleDataController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final current = controller.currentStep;
    final finished = controller.finishedCount;
    final total = controller.runnableCount;
    final headline = switch (current) {
      final step? => 'Step ${finished + 1} of $total: ${step.title}',
      null when controller.isRunning => 'Starting…',
      null when summary.notRun > 0 => 'Stopped after $finished of $total writes',
      null => 'Done: $finished writes',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          WavyProgressIndicator(value: controller.progress, semanticsLabel: 'Sample data'),
          Text(headline, style: Theme.of(context).textTheme.titleSmallEmphasized),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (summary.saved > 0)
                StatusPill(label: '${summary.saved} saved', tone: StatusTone.success, icon: Icons.check),
              if (summary.notSaved > 0)
                StatusPill(label: '${summary.notSaved} not saved', tone: StatusTone.warning, icon: Icons.block),
              if (summary.failed > 0)
                StatusPill(label: '${summary.failed} failed', tone: StatusTone.error, icon: Icons.error_outline),
              if (summary.skipped > 0) StatusPill(label: '${summary.skipped} skipped', icon: Icons.redo),
            ],
          ),
          // A write that returns false usually lacks its write permission.
          if (summary.notSaved > 0 && !controller.isRunning) const Text('Request access, then write again.'),
        ],
      ),
    );
  }
}

/// What the last `requestAuthorization` returned, as a pill under the buttons, or its error.
class _AccessResult extends StatelessWidget {
  const _AccessResult({required this.access, required this.onRetry});

  final AsyncValue<bool> access;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (access) {
      // On iOS true only says that HealthKit handled the request, not what was granted.
      AsyncData(:final value) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: value
              ? const StatusPill(label: 'Access requested', tone: StatusTone.success, icon: Icons.check)
              : const StatusPill(label: 'Access not granted', tone: StatusTone.warning, icon: Icons.block),
        ),
      ),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ErrorCard(error: error, onRetry: onRetry),
      ),
      AsyncIdle() || AsyncLoading() => const SizedBox(width: double.infinity),
    };
    const motion = ExpressiveMotion.spatialDefault;
    return AnimatedSize(duration: motion.duration, curve: motion, alignment: Alignment.topCenter, child: child);
  }
}
