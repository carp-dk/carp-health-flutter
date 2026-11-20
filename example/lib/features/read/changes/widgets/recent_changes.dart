/// The list of recent changes in Read > Changes.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';

import '../../widgets/segmented_sliver_list.dart';
import '../changes_controller.dart';
import 'change_entry_tile.dart';

/// The slivers of the recent changes: a header, then a [ChangeEntryTile] for each record the syncs since
/// the token was made touched (newest first, at most [ChangesController.recentCapacity]) in a lazily
/// built segmented list, or an [EmptyState] that says how to make changes. Nothing before a token exists.
class RecentChanges extends StatelessWidget {
  /// Creates the list of [controller]'s recent changes.
  const RecentChanges({super.key, required this.controller});

  /// The Changes section's controller.
  final ChangesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.token == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final recent = controller.recent;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Recent changes',
            trailing: recent.isEmpty ? null : StatusPill(label: formatNumber(recent.length), tone: StatusTone.info),
          ),
        ),
        if (recent.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.history_toggle_off,
              shape: ExpressiveShape.cookie7,
              title: controller.sync is AsyncIdle ? 'Not synced yet' : 'No changes yet',
              message: 'Write or edit health data, then fetch changes.',
              action: FilledButton.tonalIcon(
                onPressed: () => AppNavigation.goTo(context, AppDestination.write),
                icon: const Icon(Icons.edit_note),
                label: const Text('Go to Write'),
              ),
            ),
          )
        else
          SegmentedSliverList(
            itemCount: recent.length,
            itemBuilder: (context, index) => ChangeEntryTile(entry: recent[index]),
          ),
      ],
    );
  }
}
