/// The details of a workout route: its shape, length and time, and where it starts and ends.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';
import 'package:health_example/shared/data_point/layout/metric_grid.dart';

import 'route_preview.dart';

/// A [WorkoutRouteHealthValue]: a drawing of the route, its locations, length, time and altitudes as
/// figures, its first and last location, and the workout it belongs to.
///
/// Without the Exercise routes permission, Health Connect returns another app's route without its
/// locations and the plugin marks the data point with `route_requires_consent` in its metadata
/// (README, "Writing workout routes"); the view explains that instead of showing an empty route.
class RouteValueView extends StatelessWidget {
  /// Creates the view of [value], the value of [point].
  const RouteValueView({super.key, required this.point, required this.value});

  /// The data point.
  final HealthDataPoint point;

  /// Its value.
  final WorkoutRouteHealthValue value;

  @override
  Widget build(BuildContext context) {
    final locations = value.locations;
    final needsConsent = locations.isEmpty && point.metadata?['route_requires_consent'] == true;
    final altitudes = [for (final location in locations) ?location.altitude];
    // Whole metres: the locations are no more precise than that.
    final (distance, distanceUnit) = splitAmount(
      formatNumericValue(routeDistance(locations).roundToDouble(), HealthDataUnit.METER),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Route', subtitle: 'WorkoutRouteHealthValue'),
        if (needsConsent)
          const ExpressiveCard(
            variant: ExpressiveCardVariant.tonal,
            child: Row(
              spacing: 16,
              children: [
                Icon(Icons.lock_outline),
                Expanded(
                  child: Text(
                    'Health Connect returned this route without its locations: the app has not been '
                    'granted access to the routes of other apps.',
                  ),
                ),
              ],
            ),
          ),
        if (locations.isNotEmpty) ...[
          ExpressiveCard(
            padding: const EdgeInsets.all(8),
            child: SizedBox(height: 180, child: RoutePreview(locations: locations)),
          ),
          const SizedBox(height: 8),
          MetricGrid(
            tiles: [
              MetricTile(
                label: 'Locations',
                value: formatNumber(locations.length),
                icon: Icons.place_outlined,
                shape: ExpressiveShape.clover4,
              ),
              MetricTile(
                label: 'Distance',
                value: distance,
                unit: distanceUnit,
                icon: Icons.route,
                shape: ExpressiveShape.pill,
                footnote: 'Between the locations',
              ),
              MetricTile(
                label: 'Duration',
                value: formatDuration(locations.last.timestamp.difference(locations.first.timestamp)),
                icon: Icons.timer_outlined,
                shape: ExpressiveShape.cookie9,
              ),
              if (altitudes.isNotEmpty)
                MetricTile(
                  label: 'Altitude',
                  value:
                      '${formatNumber(altitudes.reduce((a, b) => a < b ? a : b), maxDecimals: 0)}–'
                      '${formatNumber(altitudes.reduce((a, b) => a > b ? a : b), maxDecimals: 0)}',
                  unit: 'm',
                  icon: Icons.terrain_outlined,
                  shape: ExpressiveShape.verySunny,
                ),
            ],
          ),
        ],
        DetailSection(
          title: 'Start and end',
          children: [
            if (locations.isNotEmpty) ...[
              DetailField(label: 'Start', value: _describe(locations.first), icon: Icons.trip_origin),
              DetailField(label: 'End', value: _describe(locations.last), icon: Icons.sports_score),
            ] else
              const DetailField(label: 'Locations', value: 'None'),
            if (value.workoutUuid case final workout?)
              DetailField(label: 'Workout UUID', value: workout, copyable: true, monospace: true),
          ],
        ),
      ],
    );
  }

  /// Where and when [location] was recorded, such as "55.78562, 12.52178 · 07:05:09".
  static String _describe(WorkoutRouteLocation location) =>
      '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)} · '
      '${formatTime(location.timestamp, withSeconds: true)}';
}
