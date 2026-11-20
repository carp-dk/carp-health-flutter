/// Read > Query: the data points of chosen types in a time range.
///
/// Demonstrates `Health.getHealthDataFromTypes` (all at once, with `limit`, `preferredUnits` and
/// `recordingMethodsToFilter`), `Health.getHealthDataPages` (a lazy, cancellable stream of
/// `HealthDataPage`s with `pageSize`, `isLastPageForType` and, on Android, `readPermissionDenied`) and
/// `Health.removeDuplicates`. The [QueryController] makes the calls.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import 'query_controller.dart';
import 'query_form.dart';
import 'query_progress_card.dart';
import 'query_results.dart';

/// The Query section as one sliver: the [QueryForm], a [QueryProgressCard] while a read runs, an
/// [ErrorCard] when a read failed, and the [QueryResults]. It rebuilds whenever [controller] changes;
/// the results list stays lazy, so a long result does not slow the form down.
class QueryView extends StatelessWidget {
  /// Creates the Query section of [controller], with the app's [services].
  const QueryView({super.key, required this.controller, required this.services});

  /// The section's controller.
  final QueryController controller;

  /// The app's services: the type catalog, the plugin settings and the platform.
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    const motion = ExpressiveMotion.spatialDefault;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final result = controller.result;
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: QueryForm(controller: controller, catalog: services.catalog, settings: services.settings),
            ),
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: motion.duration,
                curve: motion,
                alignment: Alignment.topCenter,
                child: controller.isReading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: QueryProgressCard(controller: controller),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
            if (result case AsyncError(:final error))
              SliverPadding(
                padding: const EdgeInsets.only(top: 24),
                sliver: SliverToBoxAdapter(
                  child: ErrorCard(error: error, onRetry: controller.canRead ? controller.read : null),
                ),
              ),
            if (result case AsyncIdle())
              const SliverToBoxAdapter(
                child: EmptyState(icon: Icons.manage_search, shape: ExpressiveShape.cookie12, title: 'Nothing read yet'),
              ),
            if (result.valueOrNull case final value?)
              QueryResults(controller: controller, result: value, isAndroid: services.capabilities.isAndroid),
          ],
        );
      },
    );
  }
}
