/// The details of a workout: its totals, what HealthKit records about it, its swimming laps and its
/// events.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';
import 'package:health_example/shared/data_point/layout/metric_grid.dart';

import 'swimming_view.dart';
import 'workout_events_view.dart';

/// A [WorkoutHealthValue]: the totals as big figures, then the workout's other fields, the
/// [HealthDataPoint.workoutSummary], the swimming details and the events.
///
/// Totals are null when the platform has none. On Android they count the records of the app that
/// wrote the workout (distance, total calories and steps); on iOS they are HealthKit's own totals of
/// the workout, which also has its active time, METs, elevation, weather, speeds and events.
class WorkoutValueView extends StatelessWidget {
  /// Creates the view of [value], the value of [point].
  const WorkoutValueView({super.key, required this.point, required this.value});

  /// The data point.
  final HealthDataPoint point;

  /// Its value.
  final WorkoutHealthValue value;

  @override
  Widget build(BuildContext context) {
    final summary = point.workoutSummary;
    final events = value.workoutEvents ?? const <WorkoutEvent>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Totals', subtitle: 'WorkoutHealthValue'),
        MetricGrid(tiles: _totals()),
        DetailSection(title: 'Workout', children: _fields()),
        if (summary != null)
          DetailSection(
            title: 'Workout summary',
            subtitle: 'HealthDataPoint.workoutSummary',
            children: [
              DetailField(label: 'Workout type', value: summary.workoutType),
              DetailField(label: 'Distance', value: '${formatNumber(summary.totalDistance)} m'),
              DetailField(label: 'Energy burned', value: '${formatNumber(summary.totalEnergyBurned)} kcal'),
              DetailField(label: 'Steps', value: formatNumber(summary.totalSteps)),
            ],
          ),
        if (value.swimming case final swimming?) SwimmingView(details: swimming),
        if (events.isNotEmpty) WorkoutEventsView(events: events),
      ],
    );
  }

  /// The totals the workout has, as metric tiles.
  List<Widget> _totals() {
    final (distance, distanceUnit) = splitAmount(
      value.totalDistance == null
          ? null
          : formatNumericValue(value.totalDistance!, value.totalDistanceUnit ?? HealthDataUnit.METER),
    );
    return [
      MetricTile(
        label: 'Duration',
        value: formatDuration(point.dateTo.difference(point.dateFrom)),
        icon: Icons.timer_outlined,
        shape: ExpressiveShape.cookie9,
      ),
      // HealthKit's duration leaves out the pauses.
      if (value.duration case final seconds?)
        MetricTile(
          label: 'Active time',
          value: formatDuration(Duration(milliseconds: (seconds * 1000).round())),
          icon: Icons.timelapse,
          shape: ExpressiveShape.cookie6,
        ),
      if (distance != null)
        MetricTile(
          label: 'Distance',
          value: distance,
          unit: distanceUnit,
          icon: Icons.route,
          shape: ExpressiveShape.pill,
        ),
      if (value.totalEnergyBurned case final energy?)
        MetricTile(
          label: 'Energy',
          value: formatNumber(energy),
          unit: formatUnit(value.totalEnergyBurnedUnit ?? HealthDataUnit.KILOCALORIE),
          icon: Icons.local_fire_department_outlined,
          shape: ExpressiveShape.sunny,
        ),
      if (value.totalSteps case final steps?)
        MetricTile(
          label: 'Steps',
          value: formatNumber(steps),
          icon: Icons.directions_walk,
          shape: ExpressiveShape.flower,
        ),
      if (value.totalFlightsClimbed case final flights?)
        MetricTile(label: 'Flights', value: formatNumber(flights), icon: Icons.stairs, shape: ExpressiveShape.cookie4),
      if (value.totalSwimmingStrokeCount case final strokes?)
        MetricTile(label: 'Strokes', value: formatNumber(strokes), icon: Icons.pool, shape: ExpressiveShape.clover4),
    ];
  }

  /// The workout's other fields, those it has.
  List<Widget> _fields() => [
    DetailField(
      label: 'Activity',
      value: '${formatEnumName(value.workoutActivityType)} (${value.workoutActivityType.name})',
    ),
    if (value.indoorWorkout case final indoors?) DetailField(label: 'Indoors', value: indoors ? 'Yes' : 'No'),
    if (value.avgMets case final mets?)
      DetailField(label: 'Average intensity', value: '${formatNumber(mets, maxDecimals: 1)} METs (kcal/kg/h)'),
    if (value.elevationAscended case final up?) DetailField(label: 'Elevation gained', value: '${formatNumber(up)} m'),
    if (value.elevationDescended case final down?)
      DetailField(label: 'Elevation lost', value: '${formatNumber(down)} m'),
    if (value.averageSpeed case final speed?) DetailField(label: 'Average speed', value: _speed(speed)),
    if (value.maximumSpeed case final speed?) DetailField(label: 'Top speed', value: _speed(speed)),
    if (value.weatherTemperature case final temperature?)
      DetailField(label: 'Weather temperature', value: '${formatNumber(temperature, maxDecimals: 1)} °C'),
    // HealthKit stores the humidity as a fraction: 0.55 is 55 %.
    if (value.weatherHumidity case final humidity?)
      DetailField(label: 'Weather humidity', value: '${formatNumber(humidity * 100, maxDecimals: 0)}%'),
  ];

  /// A speed in m/s, with km/h for reading.
  static String _speed(num metersPerSecond) =>
      '${formatNumber(metersPerSecond)} m/s (${formatNumber(metersPerSecond * 3.6, maxDecimals: 1)} km/h)';
}
