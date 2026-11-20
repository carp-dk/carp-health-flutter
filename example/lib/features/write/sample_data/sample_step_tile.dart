/// One row of the sample data's live result list: a step, and what its plugin call returned.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/open_by_uuid.dart';
import 'package:health_example/shared/visuals/type_icon.dart';
import 'package:health_example/shared/widgets/error_dialog.dart';

import '../forms/common/write_outcome.dart';
import 'sample_step.dart';

/// A [step] with its [result]: the value before it runs, a loading indicator while it runs, then whether
/// it was saved (with the start of its UUID, when the method returns one), or why it was skipped
/// ([skipReason]).
///
/// The status icon springs from one state to the next. A saved record with a UUID opens with
/// `getHealthDataByUUID` when tapped; a failed step opens the full error.
class SampleStepTile extends StatelessWidget {
  /// Creates the row of [step].
  const SampleStepTile({super.key, required this.step, required this.result, this.skipReason});

  /// The step.
  final SampleStep step;

  /// What the step's call did so far.
  final AsyncValue<WriteOutcome> result;

  /// Why the device skips the step, or null when it runs.
  final String? skipReason;

  @override
  Widget build(BuildContext context) {
    final skipped = skipReason != null;
    final onlyOn = step.onlyOn;
    return ListTile(
      enabled: !skipped,
      leading: _StepStatus(step: step, result: result, skipped: skipped),
      title: Text(step.title),
      subtitle: Text(_subtitle(), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: onlyOn == null
          ? null
          : (onlyOn == HealthPlatformType.appleHealth ? const PlatformBadge.ios() : const PlatformBadge.android()),
      onTap: _onTap(context),
    );
  }

  /// The value and how its write went, or why the step did not run.
  String _subtitle() {
    if (skipReason case final reason?) return reason;
    final value = step.description;
    return switch (result) {
      AsyncIdle() => value,
      AsyncLoading() => '$value · writing…',
      AsyncData(value: WriteOutcome(success: true, :final uuid?)) => '$value · ${_short(uuid)}',
      AsyncData(value: WriteOutcome(success: true)) => '$value · saved',
      AsyncData() => '$value · not saved',
      AsyncError(:final error) => ErrorInfo.from(error).title,
    };
  }

  /// The start of a UUID: enough to tell records apart.
  static String _short(String uuid) => uuid.length > 8 ? '${uuid.substring(0, 8)}…' : uuid;

  /// Opens the saved record or the error; null when there is nothing to open.
  VoidCallback? _onTap(BuildContext context) => switch (result) {
    AsyncData(value: WriteOutcome(:final uuid?, :final type)) => () => openDataPointByUuid(
      context,
      uuid: uuid,
      type: type,
    ),
    AsyncError(:final error) => () => showErrorDialog(context, error),
    _ => null,
  };
}

/// The status icon of a step: the type's icon before it runs, a loading indicator while it runs, then a
/// check, a "not saved" or an error shape, or a muted skip icon.
class _StepStatus extends StatelessWidget {
  const _StepStatus({required this.step, required this.result, required this.skipped});

  final SampleStep step;
  final AsyncValue<WriteOutcome> result;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = ExpressiveStatusColors.of(context);
    const size = 40.0;
    final (String key, Widget child) = switch (result) {
      _ when skipped => (
        'skipped',
        ShapedIcon(
          icon: Icons.redo,
          shape: ExpressiveShape.circle,
          size: size,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
      ),
      AsyncIdle() => ('idle', TypeIcon(type: step.type, size: size)),
      AsyncLoading() => ('loading', const ExpressiveLoadingIndicator(size: size, semanticsLabel: 'Writing')),
      AsyncData(value: final outcome) when outcome.success => (
        'saved',
        ShapedIcon(icon: Icons.check, size: size, background: status.success, foreground: status.onSuccess),
      ),
      AsyncData() => (
        'not-saved',
        ShapedIcon(
          icon: Icons.block,
          shape: ExpressiveShape.puffy,
          size: size,
          background: status.warning,
          foreground: status.onWarning,
        ),
      ),
      AsyncError() => (
        'failed',
        ShapedIcon(
          icon: Icons.error_outline,
          shape: ExpressiveShape.sunny,
          size: size,
          background: scheme.error,
          foreground: scheme.onError,
        ),
      ),
    };
    const motion = ExpressiveMotion.spatialFast;
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: motion.duration,
        switchInCurve: motion,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation.drive(ExpressiveMotion.clampToUnit), child: child),
        ),
        child: KeyedSubtree(key: ValueKey(key), child: child),
      ),
    );
  }
}
