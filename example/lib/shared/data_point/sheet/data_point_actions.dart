/// The data point sheet's actions on the record, Re-read by UUID and Delete, with their progress and
/// what they returned.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_text.dart';
import 'package:health_example/shared/data_point/sheet/data_point_sheet_controller.dart';
import 'package:health_example/shared/widgets/error_card.dart';

/// Asks the user to confirm deleting [point], explaining that apps can delete only their own data.
/// Returns whether to delete.
Future<bool> confirmDataPointDelete(BuildContext context, HealthDataPoint point) async {
  final scheme = Theme.of(context).colorScheme;
  final platform = point.sourcePlatform == HealthPlatformType.appleHealth ? 'Apple Health' : 'Health Connect';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Delete this record?'),
      content: Text(
        'deleteByUUID removes this ${point.type.label} record from $platform, so that no app reads it any more.'
        '\n\nApps can delete only the data they wrote themselves: for a record that another app wrote, the '
        'plugin returns false and the record stays.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The two buttons of the data point sheet and the outcome of the last call under them.
///
/// "Re-read by UUID" runs [DataPointSheetController.rereadByUuid]; "Delete" calls [onDelete], which
/// confirms and then runs [DataPointSheetController.deleteByUuid]. Both are disabled while a call runs
/// and for a point without a UUID.
class DataPointActions extends StatelessWidget {
  /// Creates the actions on [controller]'s point.
  const DataPointActions({super.key, required this.controller, required this.onDelete});

  /// The sheet's state and calls.
  final DataPointSheetController controller;

  /// Confirms and deletes the record.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = controller.hasUuid && !controller.isBusy && !controller.isDeleted;
    const motion = ExpressiveMotion.spatialDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One height for both buttons, also when large text wraps one label onto two lines.
        IntrinsicHeight(
          child: Row(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? controller.rereadByUuid : null,
                  icon: controller.lookup.isLoading ? const _Busy() : const Icon(Icons.refresh),
                  label: const Text('Re-read by UUID'),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: enabled ? onDelete : null,
                  icon: controller.deletion.isLoading ? const _Busy() : const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _outcomes()),
        ),
      ],
    );
  }

  /// What the calls returned, each in a card or pill under the buttons.
  List<Widget> _outcomes() {
    Widget spaced(Widget child) => Padding(padding: const EdgeInsets.only(top: 12), child: child);
    return [
      if (!controller.hasUuid)
        spaced(
          const _Note(
            icon: Icons.info_outline,
            text:
                'This data point has no UUID: interval data are aggregates, not records, so it cannot be read '
                'again or deleted by UUID.',
          ),
        ),
      ...switch (controller.lookup) {
        AsyncData(value: _?) => [
          spaced(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(
                label: 'Re-read at ${formatTime(controller.lookedUpAt ?? DateTime.now(), withSeconds: true)}',
                tone: StatusTone.success,
                icon: Icons.check,
              ),
            ),
          ),
        ],
        AsyncData() => [spaced(_Note(icon: Icons.search_off, text: uuidNotFoundMessage(controller.point.type)))],
        AsyncError(:final error) => [spaced(ErrorCard(error: error, onRetry: controller.rereadByUuid))],
        _ => const <Widget>[],
      },
      ...switch (controller.deletion) {
        AsyncData(value: false) => [
          spaced(
            const _Note(
              icon: Icons.block,
              text:
                  'deleteByUUID returned false: nothing was deleted. Apps can delete only the records they wrote '
                  'themselves, and only records that still exist.',
            ),
          ),
        ],
        AsyncError(:final error) => [spaced(ErrorCard(error: error, onRetry: onDelete))],
        _ => const <Widget>[],
      },
    ];
  }
}

/// A small loading indicator in place of a button's icon.
class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) => const ExpressiveLoadingIndicator(size: 20, semanticsLabel: 'Working');
}

/// A tonal card with an icon and an explanation.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ExpressiveCard(
      variant: ExpressiveCardVariant.tonal,
      padding: const EdgeInsets.all(16),
      radius: ExpressiveShapes.largeIncreased,
      child: Row(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
