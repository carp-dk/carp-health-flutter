part of '../../main.dart';

/// Writing a sample workout route and attaching it to a recent workout.
extension _WriteWorkoutRouteActions on HealthAppState {
  /// Writes a sample workout route and associates it with a workout.
  Future<void> writeWorkoutRoute() async {
    if (!(Platform.isIOS || Platform.isAndroid)) {
      debugPrint('Workout routes are only supported on iOS or Android.');
      return;
    }

    if (Platform.isAndroid && health.healthConnectSdkStatus != HealthConnectSdkStatus.sdkAvailable) {
      debugPrint('Workout routes on Android require Health Connect to be available.');
      return;
    }

    String? builderId;
    try {
      builderId = await health.startWorkoutRoute();

      List<HealthDataPoint> workouts = await health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().add(const Duration(hours: 3)),
      );

      if (workouts.isEmpty) {
        final now = DateTime.now();
        final fallbackStart = now.subtract(const Duration(minutes: 30));
        final fallbackEnd = now;

        await health.writeWorkoutData(
          activityType: HealthWorkoutActivityType.WALKING,
          start: fallbackStart,
          end: fallbackEnd,
          totalDistance: 1500,
          totalEnergyBurned: 150,
        );

        // Add a small delay to allow the workout to be written before querying
        await Future.delayed(const Duration(milliseconds: 500));

        workouts = await health.getHealthDataFromTypes(
          types: const [HealthDataType.WORKOUT],
          startTime: fallbackStart.subtract(const Duration(minutes: 1)),
          endTime: fallbackEnd.add(const Duration(minutes: 1)),
        );

        // Retry once more if still empty after a longer delay
        if (workouts.isEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          workouts = await health.getHealthDataFromTypes(
            types: const [HealthDataType.WORKOUT],
            startTime: fallbackStart.subtract(const Duration(minutes: 1)),
            endTime: fallbackEnd.add(const Duration(minutes: 1)),
          );
        }
      }

      workouts.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      if (workouts.isEmpty) {
        throw StateError(
          'Unable to find a workout to attach the route. The created workout may not be immediately available. Try running a workout manually first, or wait a moment and try again.',
        );
      }

      final workoutPoint = workouts.first;
      final routeLocations = _buildSampleWorkoutRoute(workoutPoint.dateFrom, workoutPoint.dateTo);

      await health.insertWorkoutRouteData(builderId: builderId, locations: routeLocations);

      final routeUuid = await health.finishWorkoutRoute(
        builderId: builderId,
        workoutUuid: workoutPoint.uuid,
        metadata: const {'sample_source': 'health_example_app'},
      );

      debugPrint('Created workout route $routeUuid for workout ${workoutPoint.uuid}.');

      await fetchData();
    } catch (error) {
      debugPrint('Exception in writeWorkoutRoute: $error');
      if (builderId != null) {
        try {
          await health.discardWorkoutRoute(builderId);
        } catch (discardError) {
          debugPrint('Failed to discard workout route builder: $discardError');
        }
      }
      if (mounted) {
        setState(() => _state = AppState.DATA_NOT_ADDED);
      }
    }
  }

  List<WorkoutRouteLocation> _buildSampleWorkoutRoute(DateTime start, DateTime end) {
    final clampedEnd = end.subtract(const Duration(seconds: 1));
    if (!clampedEnd.isAfter(start)) {
      throw ArgumentError('Workout end time must be after start time.');
    }

    final coordinates = <List<double>>[
      [37.334900, -122.009020],
      [37.335020, -122.008720],
      [37.335280, -122.008430],
      [37.335540, -122.008250],
      [37.335780, -122.008000],
    ];

    final intervalMillis =
        (clampedEnd.millisecondsSinceEpoch - start.millisecondsSinceEpoch) ~/ (coordinates.length + 1);
    final interval = Duration(milliseconds: intervalMillis.clamp(1, 600000));

    return List<WorkoutRouteLocation>.generate(coordinates.length, (index) {
      final pointTime = start.add(interval * (index + 1));
      final timestamp = pointTime.isBefore(clampedEnd) ? pointTime : clampedEnd;
      final latitude = coordinates[index][0];
      final longitude = coordinates[index][1];

      return WorkoutRouteLocation(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        altitude: 10 + index * 1.5,
        horizontalAccuracy: 5.0,
        verticalAccuracy: 8.0,
        speed: 1.4 + index * 0.1,
        course: ((index * 45) % 360).toDouble(),
      );
    });
  }
}
