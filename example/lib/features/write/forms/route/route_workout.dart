/// A workout that the Workout route form can attach a route to.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';

/// A workout to attach a route to: its UUID (what `finishWorkoutRoute` takes as `workoutUuid`), its
/// activity, its time and who wrote it.
@immutable
class RouteWorkout {
  /// Creates the workout [uuid] of [activity] from [start] to [end], written by [sourceName].
  const RouteWorkout({
    required this.uuid,
    required this.activity,
    required this.start,
    required this.end,
    this.sourceName = '',
    this.writtenHere = false,
  });

  /// The workout read as [point], a `WORKOUT` data point; [writtenHere] when this app wrote it in this
  /// session (its UUID is in the recent writes).
  factory RouteWorkout.fromPoint(HealthDataPoint point, {bool writtenHere = false}) => RouteWorkout(
    uuid: point.uuid,
    activity: switch (point.value) {
      WorkoutHealthValue(:final workoutActivityType) => workoutActivityType,
      _ => null,
    },
    start: point.dateFrom,
    end: point.dateTo,
    sourceName: point.sourceName,
    writtenHere: writtenHere,
  );

  /// The workout's UUID: the HealthKit workout's, or the Health Connect exercise session's id.
  final String uuid;

  /// The workout's activity, or null when the point had no workout value.
  final HealthWorkoutActivityType? activity;

  /// When the workout started.
  final DateTime start;

  /// When the workout ended.
  final DateTime end;

  /// The app or device that wrote the workout.
  final String sourceName;

  /// Whether this app wrote the workout in this session.
  final bool writtenHere;

  /// The activity in words, such as "Running".
  String get label => activity == null ? 'Workout' : formatEnumName(activity!);

  /// When the workout took place, such as "Today, 07:00 – 07:30".
  String get time => formatTimeRange(start, end);

  @override
  bool operator ==(Object other) => other is RouteWorkout && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;

  @override
  String toString() => 'RouteWorkout($uuid, $label, $time)';
}
