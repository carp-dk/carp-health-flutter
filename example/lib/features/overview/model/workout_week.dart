/// This week's workouts, as `getHealthDataFromTypes` reads them for the overview: how many, how
/// long in total, and the newest.
library;

import 'package:health/health.dart';

/// The [workouts] read since Monday, newest first.
class WorkoutWeek {
  /// Collects the workout data points [points] (other types are ignored), newest first.
  WorkoutWeek(Iterable<HealthDataPoint> points)
    : workouts = List.unmodifiable(
        points.where((point) => point.value is WorkoutHealthValue).toList()
          // Android reads oldest first and iOS newest first: sort, so both read the same.
          ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom)),
      );

  /// The workouts, newest first.
  final List<HealthDataPoint> workouts;

  /// How many workouts there were.
  int get count => workouts.length;

  /// The time spent in all of them together.
  Duration get totalDuration =>
      workouts.fold(Duration.zero, (total, workout) => total + workout.dateTo.difference(workout.dateFrom));

  /// The newest workout, or null when there were none.
  HealthDataPoint? get latest => workouts.isEmpty ? null : workouts.first;

  /// The activity of the newest workout, such as `HealthWorkoutActivityType.RUNNING`.
  HealthWorkoutActivityType? get latestActivity => switch (latest?.value) {
    WorkoutHealthValue(:final workoutActivityType) => workoutActivityType,
    _ => null,
  };
}
