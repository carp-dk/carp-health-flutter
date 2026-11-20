/// The records this app wrote in this session, as chips that look them up by UUID.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';

import '../widgets/card_title.dart';

/// A card with a chip for each of the newest [maxChips] writes in [recentWrites] that have a UUID
/// (those of the `...UUID` write methods, such as `writeHealthDataUUID`), which its info button names.
/// Tapping a chip reports the write through [onSelected], which looks it up. Before any such write, the
/// card links to the Write page.
class RecentWriteChips extends StatelessWidget {
  /// Creates the chips of [recentWrites].
  const RecentWriteChips({super.key, required this.recentWrites, required this.onSelected, this.enabled = true});

  /// The app's log of what it wrote.
  final RecentWrites recentWrites;

  /// Called with the write whose chip was tapped.
  final ValueChanged<RecentWrite> onSelected;

  /// Whether the chips can be tapped (not while a lookup runs).
  final bool enabled;

  /// The most chips shown: the newest writes.
  static const int maxChips = 12;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: recentWrites,
      builder: (context, _) {
        final writes = recentWrites.withUuid.take(maxChips).toList();
        if (writes.isEmpty) {
          return ExpressiveCard(
            variant: ExpressiveCardVariant.outlined,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
            child: Row(
              spacing: 12,
              children: [
                const ShapedIcon(icon: Icons.history_edu, shape: ExpressiveShape.clover4, size: 36),
                Expanded(
                  child: Text(
                    'No recent writes',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                TextButton(
                  onPressed: () => AppNavigation.goTo(context, AppDestination.write),
                  child: const Text('Go to Write'),
                ),
              ],
            ),
          );
        }
        return ExpressiveCard(
          variant: ExpressiveCardVariant.tonal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const CardTitle(icon: Icons.history_edu, shape: ExpressiveShape.clover4, title: 'Recent writes'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final write in writes)
                    ActionChip(
                      avatar: Icon(write.type.icon),
                      label: Text('${write.type.label} · ${write.description}'),
                      tooltip: '${write.uuid} · ${formatRelative(write.at)}',
                      onPressed: enabled ? () => onSelected(write) : null,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
