/// The route the Workout route form writes, drawn, with its figures.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/value_views/route/route_preview.dart';

/// [locations] drawn as a route (the shared `RoutePreview`) on a surface container, with the number of
/// locations, the distance between them and the time from the first to the last.
class RoutePreviewPanel extends StatelessWidget {
  /// Creates the panel for [locations].
  const RoutePreviewPanel({super.key, required this.locations});

  /// The route's locations, in order.
  final List<WorkoutRouteLocation> locations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timed = locations.length > 1;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            SizedBox(
              height: 160,
              child: locations.isEmpty
                  ? Center(child: Icon(Icons.route, size: 48, color: scheme.outline))
                  : RoutePreview(locations: locations),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(label: '${locations.length} locations', tone: StatusTone.info, icon: Icons.place_outlined),
                if (timed) ...[
                  StatusPill(
                    label: '${formatNumber(routeDistance(locations), maxDecimals: 0)} m',
                    tone: StatusTone.info,
                    icon: Icons.straighten,
                  ),
                  StatusPill(
                    label:
                        '${formatTime(locations.first.timestamp, withSeconds: true)} – '
                        '${formatTime(locations.last.timestamp, withSeconds: true)}',
                    tone: StatusTone.neutral,
                    icon: Icons.schedule,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
