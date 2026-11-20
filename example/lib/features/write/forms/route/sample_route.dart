/// The sample route the Workout route form writes: a short walk of five GPS locations.
library;

import 'package:health/health.dart';

/// Builds the sample route, the five locations the example has always written (a walk near Apple Park,
/// Cupertino), timed inside a workout.
///
/// Health Connect rejects a route with a location outside its workout's session, and HealthKit expects
/// the locations while the workout ran, so [over] spreads them evenly between the workout's start and a
/// second before its end, in ascending order as `insertWorkoutRouteData` expects.
abstract final class SampleRoute {
  /// The latitude and longitude of each location, in degrees.
  static const List<(double latitude, double longitude)> coordinates = [
    (37.334900, -122.009020),
    (37.335020, -122.008720),
    (37.335280, -122.008430),
    (37.335540, -122.008250),
    (37.335780, -122.008000),
  ];

  /// The longest gap between two locations.
  static const Duration maxInterval = Duration(minutes: 10);

  /// Whether a workout from [start] to [end] is long enough for the route: it must last more than a second.
  static bool fits(DateTime start, DateTime end) => end.subtract(const Duration(seconds: 1)).isAfter(start);

  /// The sample route in a workout from [start] to [end]: the [coordinates] at even intervals (at most
  /// [maxInterval]) after [start], each with an altitude, accuracies, a walking speed and a course.
  ///
  /// Throws an [ArgumentError] when the workout is too short ([fits]).
  static List<WorkoutRouteLocation> over(DateTime start, DateTime end) {
    final last = end.subtract(const Duration(seconds: 1));
    if (!last.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'The workout must last more than a second to hold a route');
    }
    final step = last.difference(start).inMilliseconds ~/ (coordinates.length + 1);
    final interval = Duration(milliseconds: step.clamp(1, maxInterval.inMilliseconds));
    return [
      for (final (index, (latitude, longitude)) in coordinates.indexed)
        WorkoutRouteLocation(
          latitude: latitude,
          longitude: longitude,
          timestamp: _earlier(start.add(interval * (index + 1)), last),
          altitude: 10 + index * 1.5,
          horizontalAccuracy: 5,
          verticalAccuracy: 8,
          speed: 1.4 + index * 0.1,
          course: (index * 45 % 360).toDouble(),
        ),
    ];
  }

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
