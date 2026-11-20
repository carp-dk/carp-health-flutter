/// What the last write of a form returned, under its write button.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/open_by_uuid.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import 'write_form_controller.dart';
import 'write_outcome.dart';

/// The result of [controller]'s last write: nothing before the first, the `ErrorCard` of what the plugin
/// threw (with [onRetry]), or a compact card with what was saved.
///
/// The card's info button shows what the write method returned. A saved record that has a UUID can be
/// viewed (`getHealthDataByUUID`). When the method returned false (or an empty UUID), the info sheet says
/// why that happens and the card offers to request write access with [WriteFormController.requestAccess].
/// Changes spring in and out.
class WriteOutcomeView extends StatelessWidget {
  /// Creates the view of [controller]'s last write.
  const WriteOutcomeView({super.key, required this.controller, required this.onRetry});

  /// The form's controller.
  final WriteFormController controller;

  /// Writes again, as the form's write button does.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final Widget child = switch (result) {
      AsyncError(:final error) => ErrorCard(key: const ValueKey('error'), error: error, onRetry: onRetry),
      // While a write runs, the button shows progress and the last outcome stays.
      _ => switch (result.valueOrNull) {
        final outcome? => _OutcomeCard(key: ObjectKey(outcome), outcome: outcome, controller: controller),
        null => const SizedBox(key: ValueKey('none'), width: double.infinity),
      },
    };
    const motion = ExpressiveMotion.spatialDefault;
    return AnimatedSize(
      duration: motion.duration,
      curve: motion,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: ExpressiveMotion.effectsSlow.duration, child: child),
    );
  }
}

/// The card of one outcome, in the success or warning colours.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({super.key, required this.outcome, required this.controller});

  final WriteOutcome outcome;
  final WriteFormController controller;

  @override
  Widget build(BuildContext context) {
    final colors = ExpressiveStatusColors.of(context);
    final saved = outcome.success;
    final (background, foreground) = saved ? (colors.success, colors.onSuccess) : (colors.warning, colors.onWarning);
    final uuid = outcome.uuid;
    return Material(
      color: background,
      shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 12,
              children: [
                ShapedIcon(
                  icon: saved ? Icons.check : Icons.block,
                  shape: saved ? ExpressiveShape.cookie9 : ExpressiveShape.puffy,
                  size: 36,
                  background: foreground,
                  foreground: background,
                ),
                Expanded(
                  child: Text(
                    saved ? 'Saved · ${outcome.description}' : 'Not saved',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmallEmphasized.copyWith(color: foreground),
                  ),
                ),
                IconButton(
                  tooltip: 'About the result',
                  visualDensity: VisualDensity.compact,
                  color: foreground,
                  onPressed: () => showInfoSheet(
                    context,
                    title: saved ? 'Saved' : 'Not saved',
                    code: '${outcome.method} returned ${outcome.returned}',
                    message: saved
                        ? null
                        : 'Usually the write permission is missing. Health Connect also returns false for a value '
                              'outside its range and once the write quota is used up.',
                  ),
                  icon: const Icon(Icons.info_outline),
                ),
                if (saved && uuid != null)
                  IconButton(
                    tooltip: 'View the record',
                    color: foreground,
                    onPressed: () => openDataPointByUuid(context, uuid: uuid, type: outcome.type),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
              ],
            ),
            if (!saved) _AccessRequest(controller: controller, color: foreground),
          ],
        ),
      ),
    );
  }
}

/// "Request access" and what `requestAuthorization` returned, in one line.
class _AccessRequest extends StatelessWidget {
  const _AccessRequest({required this.controller, required this.color});

  final WriteFormController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: color);
    final button = FilledButton.tonalIcon(
      onPressed: controller.requestAccess,
      icon: const Icon(Icons.lock_open),
      label: const Text('Request access'),
    );
    final String? status = switch (controller.access) {
      AsyncIdle() => null,
      AsyncLoading() => 'Requesting…',
      // On iOS `true` only means that HealthKit handled the request: the next write tells.
      AsyncData(:final value) => value ? 'Requested: write again' : 'Not granted',
      AsyncError(:final error) => 'Failed: ${ErrorInfo.from(error).title}',
    };
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (controller.access.isLoading)
          const ExpressiveLoadingIndicator(size: 32, semanticsLabel: 'Requesting access')
        else
          button,
        if (status != null) Text(status, style: style),
      ],
    );
  }
}
