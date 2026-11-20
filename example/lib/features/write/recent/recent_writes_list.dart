/// The Write page's log of what the app wrote in this session (`RecentWrites`), with View
/// (`Health.getHealthDataByUUID`) and Delete (`Health.deleteByUUID`, or `Health.deleteByClientRecordId`
/// on Android) for each record.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import 'recent_write_tile.dart';
import 'recent_writes_controller.dart';

/// A section header, then the writes of [controller]'s log, newest first, as a segmented list, or an
/// empty state before the first write. A delete that threw shows its `ErrorCard` under the list, with
/// a retry.
class RecentWritesList extends StatelessWidget {
  /// Creates the list of [controller]'s writes.
  const RecentWritesList({super.key, required this.controller});

  /// Deletes the records and keeps the state of each delete.
  final RecentWritesController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.recentWrites]),
      builder: (context, _) {
        final writes = controller.recentWrites.items;
        final failures = controller.failures;
        if (writes.isEmpty && failures.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Recent writes',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    StatusPill(label: '${writes.length}', tone: StatusTone.info),
                    TextButton(onPressed: controller.clear, child: const Text('Clear')),
                  ],
                ),
              ),
              if (writes.isNotEmpty)
                SegmentedList(
                  children: [
                    for (final write in writes)
                      RecentWriteTile(
                        write: write,
                        deleteState: controller.deleteStateOf(write),
                        deleteMethod: controller.deleteMethodOf(write),
                        onDelete: controller.canDelete(write) ? () => _confirmAndDelete(context, write) : null,
                      ),
                  ],
                ),
              if (failures.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ErrorCard(error: failures.first.$2, onRetry: () => controller.delete(failures.first.$1)),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Asks before deleting [write]'s record, then deletes it.
  Future<void> _confirmAndDelete(BuildContext context, RecentWrite write) async {
    if (await confirmRecentWriteDelete(context, write)) {
      await controller.delete(write);
    }
  }
}

/// Asks the user to confirm deleting [write]'s record, naming what was written. Returns whether to
/// delete.
Future<bool> confirmRecentWriteDelete(BuildContext context, RecentWrite write) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: Text('Delete this ${write.type.label.toLowerCase()} record?'),
      content: Text(write.description),
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
