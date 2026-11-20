/// Read > Lookup: one record by its UUID.
///
/// Demonstrates `Health.getHealthDataByUUID`, which returns the record of a type with a UUID, or null
/// when there is none (or, without the read permission, when another app wrote it). The records this
/// app wrote in the session (`RecentWrites` with UUIDs) are one tap away. The [LookupController] makes
/// the call.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/async_value_view.dart';

import '../widgets/adaptive_pair.dart';
import 'lookup_controller.dart';
import 'lookup_form.dart';
import 'lookup_result_view.dart';
import 'recent_write_chips.dart';

/// The Lookup section as one sliver: the [LookupForm] and the [RecentWriteChips] (side by side on wide
/// windows), then the result in an [AsyncValueView]: the loading indicator while the plugin reads, an
/// `ErrorCard` when it threw, and the [LookupResultView] when it answered.
class LookupView extends StatelessWidget {
  /// Creates the Lookup section of [controller], with the app's [services].
  const LookupView({super.key, required this.controller, required this.services});

  /// The section's controller.
  final LookupController controller;

  /// The app's services: the recent writes and the platform.
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // The UUID field too: the Look up button follows what is typed.
      listenable: Listenable.merge([controller, controller.uuidField]),
      builder: (context, _) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: AdaptivePair(
              first: LookupForm(controller: controller),
              second: RecentWriteChips(
                recentWrites: services.recentWrites,
                enabled: !controller.result.isLoading,
                onSelected: controller.lookUpWrite,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 24),
            sliver: SliverToBoxAdapter(
              child: AsyncValueView(
                value: controller.result,
                loadingLabel: 'Looking up…',
                onRetry: controller.lookUp,
                idle: const EmptyState(
                  icon: Icons.fingerprint,
                  shape: ExpressiveShape.cookie12,
                  title: 'Nothing looked up yet',
                ),
                data: (context, result) => LookupResultView(
                  result: result,
                  isIOS: services.capabilities.isIOS,
                  onDeleted: controller.clearResult,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
