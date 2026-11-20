/// What a `Health.delete` run did, type by type.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/type_icon.dart';
import 'package:health_example/shared/widgets/error_card.dart';
import 'package:health_example/shared/widgets/error_dialog.dart';

import 'delete_controller.dart';

/// The progress of [controller]'s current or last `delete` run (a wavy bar and the type being deleted)
/// and a row per type with what `delete` returned: a loading indicator while it runs, then "Deleted"
/// (true), "Not deleted" (false) or "Failed" (with the error's title; tap for the error). The first
/// failure also shows as an `ErrorCard`. Nothing before the first run.
class DeleteRangeResults extends StatelessWidget {
  /// Creates the results of [controller]'s run.
  const DeleteRangeResults({super.key, required this.controller});

  /// The Delete page's state and calls.
  final DeleteController controller;

  @override
  Widget build(BuildContext context) {
    final results = controller.results;
    final failure = results.map((entry) => entry.result.errorOrNull).nonNulls.firstOrNull;
    final current = controller.currentType;
    const motion = ExpressiveMotion.spatialDefault;
    return AnimatedSize(
      duration: motion.duration,
      curve: motion,
      alignment: Alignment.topCenter,
      child: results.isEmpty
          ? const SizedBox(width: double.infinity)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                WavyProgressIndicator(value: controller.finishedCount / results.length, semanticsLabel: 'Deleting'),
                Text(
                  current != null
                      ? 'Deleting ${current.label} (${controller.finishedCount + 1} of ${results.length})…'
                      : 'Deleted in ${formatTimeRange(controller.range.start, controller.range.end)}',
                  style: Theme.of(context).textTheme.titleSmallEmphasized,
                ),
                SegmentedList(
                  children: [
                    for (final entry in results)
                      ListTile(
                        leading: TypeIcon(type: entry.type, size: 40),
                        title: Text(entry.type.label),
                        subtitle: switch (entry.result) {
                          AsyncError(:final error) => Text(ErrorInfo.from(error).title),
                          _ => null,
                        },
                        trailing: _status(entry.result),
                        onTap: switch (entry.result) {
                          AsyncError(:final error) => () => showErrorDialog(context, error),
                          _ => null,
                        },
                      ),
                  ],
                ),
                if (failure != null) ErrorCard(error: failure, onRetry: controller.deleteInRange),
              ],
            ),
    );
  }

  /// The state at the end of a row.
  static Widget _status(AsyncValue<bool> result) => switch (result) {
    AsyncIdle() => const StatusPill(label: 'Waiting', icon: Icons.schedule),
    AsyncLoading() => const ExpressiveLoadingIndicator(size: 32, semanticsLabel: 'Deleting'),
    // Both platforms also answer true when the range held none of the app's data.
    AsyncData(value: true) => const StatusPill(label: 'Deleted', tone: StatusTone.success, icon: Icons.check),
    AsyncData() => const StatusPill(label: 'Not deleted', tone: StatusTone.warning, icon: Icons.block),
    AsyncError() => const StatusPill(label: 'Failed', tone: StatusTone.error, icon: Icons.error_outline),
  };
}
