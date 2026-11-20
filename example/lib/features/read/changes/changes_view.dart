/// Read > Changes (Android only): following what was added, changed and deleted in Health Connect.
///
/// Demonstrates `Health.getChangesToken` (a token for chosen types) and `Health.getChanges` (the changes
/// since a token, one page per call, called again with each `nextChangesToken` while `hasMore`), with
/// `includeSelf`, `HealthChangesResponse.changesTokenExpired` and the full resync it calls for. The changes
/// are applied to a local copy of the records, as an app that mirrors health data in its own database
/// would. iOS has no changes API (both calls return null there), so the section explains that instead of
/// calling the plugin. The [ChangesController] makes the calls.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/design/design.dart';

import '../widgets/adaptive_pair.dart';
import 'changes_controller.dart';
import 'widgets/changes_sync_card.dart';
import 'widgets/changes_token_card.dart';
import 'widgets/changes_types_card.dart';
import 'widgets/recent_changes.dart';

/// The Changes section as one sliver: the [ChangesTypesCard] and the [ChangesTokenCard] (side by side on
/// wide windows), the [ChangesSyncCard] and the [RecentChanges]. It rebuilds whenever [controller]
/// changes. On iOS it shows an [EmptyState] that explains why, with a way to Query.
class ChangesView extends StatelessWidget {
  /// Creates the Changes section of [controller], offering the types of [catalog].
  const ChangesView({super.key, required this.controller, required this.catalog, required this.onReadInQuery});

  /// The section's controller.
  final ChangesController controller;

  /// The types this device supports, to follow.
  final TypeCatalog catalog;

  /// Opens Query set up to read these types again: the full resync that an expired token calls for. With
  /// no types, Query opens as it was.
  final ValueChanged<Set<HealthDataType>> onReadInQuery;

  @override
  Widget build(BuildContext context) {
    if (!controller.isSupported) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.sync_disabled,
          shape: ExpressiveShape.cookie6,
          title: 'Health Connect only',
          message: 'Incremental change sync is available on Android.',
          // No types: Query keeps the types the user chose there.
          action: FilledButton.tonalIcon(
            onPressed: () => onReadInQuery(const {}),
            icon: const Icon(Icons.manage_search),
            label: const Text('Go to Query'),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: AdaptivePair(
              first: ChangesTypesCard(controller: controller, catalog: catalog),
              second: ChangesTokenCard(controller: controller),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverToBoxAdapter(
              child: ChangesSyncCard(
                controller: controller,
                // The token's types (rather than the chosen ones) are what the lost changes were about.
                onReadInQuery: () => onReadInQuery(controller.tokenTypes.toSet()),
              ),
            ),
          ),
          RecentChanges(controller: controller),
        ],
      ),
    );
  }
}
