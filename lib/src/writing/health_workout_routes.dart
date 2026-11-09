part of '../../health.dart';

/// Part of [Health]: writing workout routes. A route builder is started, given
/// locations batch by batch, and then finished for a workout or discarded.
// ignore: library_private_types_in_public_api
mixin HealthWorkoutRoutes on _HealthSupport {
  /// Start a new workout route recording session on iOS or Android.
  ///
  /// Returns a builder identifier that must be supplied in subsequent calls
  /// to [insertWorkoutRouteData], [finishWorkoutRoute], or
  /// [discardWorkoutRoute].
  Future<String> startWorkoutRoute() async {
    final identifier = await Health._channel.invokeMethod<String>('startWorkoutRoute');
    if (identifier == null) {
      throw PlatformException(code: 'ROUTE_ERROR', message: 'Failed to start workout route builder.');
    }
    return identifier;
  }

  /// Append a batch of [locations] to an active workout route builder.
  ///
  /// The [builderId] must come from [startWorkoutRoute]. Locations should
  /// be ordered by ascending timestamp to mirror HealthKit’s expectations.
  Future<bool> insertWorkoutRouteData({
    required String builderId,
    required List<WorkoutRouteLocation> locations,
  }) async {
    final args = <String, dynamic>{
      'builderId': builderId,
      'locations': locations.map(_serializeWorkoutRouteLocationForNative).toList(),
    };
    return await Health._channel.invokeMethod<bool>('insertWorkoutRouteData', args) == true;
  }

  /// Finalises the workout route and associates it with an existing workout.
  ///
  /// Provide the [builderId] from [startWorkoutRoute], the platform-specific
  /// [workoutUuid] (as returned from [Health.writeWorkoutData] or another
  /// mechanism), and optional [metadata] that will be stored on the resulting
  /// route.
  ///
  /// Returns the created route’s UUID string.
  Future<String> finishWorkoutRoute({
    required String builderId,
    required String workoutUuid,
    Map<String, dynamic>? metadata,
  }) async {
    final args = <String, dynamic>{
      'builderId': builderId,
      'workoutUUID': workoutUuid,
      if (metadata != null) 'metadata': Map<String, dynamic>.from(metadata),
    };
    final response = await Health._channel.invokeMapMethod<String, dynamic>('finishWorkoutRoute', args);
    final routeUuid = response?['uuid'] as String?;
    if (routeUuid == null) {
      throw PlatformException(code: 'ROUTE_ERROR', message: 'Workout route completion failed.');
    }
    return routeUuid;
  }

  /// Discards any progress for the specified workout route builder.
  ///
  /// Returns `true` if the builder existed and was discarded successfully.
  Future<bool> discardWorkoutRoute(String builderId) async {
    final args = <String, dynamic>{'builderId': builderId};
    return await Health._channel.invokeMethod<bool>('discardWorkoutRoute', args) == true;
  }
}

Map<String, dynamic> _serializeWorkoutRouteLocationForNative(WorkoutRouteLocation location) {
  final map = <String, dynamic>{
    'latitude': location.latitude,
    'longitude': location.longitude,
    'timestamp': location.timestamp.toUtc().millisecondsSinceEpoch,
  };
  void addIfNotNull(String key, Object? value) {
    if (value != null) map[key] = value;
  }

  addIfNotNull('altitude', location.altitude);
  addIfNotNull('horizontalAccuracy', location.horizontalAccuracy);
  addIfNotNull('verticalAccuracy', location.verticalAccuracy);
  addIfNotNull('speed', location.speed);
  addIfNotNull('course', location.course);
  addIfNotNull('speedAccuracy', location.speedAccuracy);
  addIfNotNull('courseAccuracy', location.courseAccuracy);

  return map;
}
