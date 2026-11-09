part of '../../health.dart';

/// A single location sample captured as part of a workout route.
///
/// Parameters:
/// * [latitude] & [longitude] - required geographic coordinates in degrees.
/// * [timestamp] - when the location sample was recorded.
/// * [altitude] - optional altitude above sea level in meters.
/// * [horizontalAccuracy] / [verticalAccuracy] - optional accuracy in meters.
/// * [speed] - optional instantaneous speed in meters/second (iOS only).
/// * [course] - optional bearing (heading) in degrees (iOS only).
/// * [speedAccuracy] - optional accuracy of speed measurement in meters/second (iOS 13.4+ only).
/// * [courseAccuracy] - optional accuracy of bearing measurement in degrees (iOS 13.4+ only).
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class WorkoutRouteLocation extends Serializable {
  double latitude;
  double longitude;
  DateTime timestamp;
  double? altitude;
  double? horizontalAccuracy;
  double? verticalAccuracy;
  double? speed;
  double? course;
  double? speedAccuracy;
  double? courseAccuracy;

  WorkoutRouteLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    this.speed,
    this.course,
    this.speedAccuracy,
    this.courseAccuracy,
  });

  factory WorkoutRouteLocation.fromHealthDataPoint(Map<String, dynamic> data) => WorkoutRouteLocation(
    latitude: (data['latitude'] as num).toDouble(),
    longitude: (data['longitude'] as num).toDouble(),
    timestamp: _timestampFrom(data),
    altitude: _nullableDouble(data['altitude']),
    horizontalAccuracy: _nullableDouble(data['horizontalAccuracy']),
    verticalAccuracy: _nullableDouble(data['verticalAccuracy']),
    speed: _nullableDouble(data['speed']),
    course: _nullableDouble(data['course']),
    speedAccuracy: _nullableDouble(data['speedAccuracy']),
    courseAccuracy: _nullableDouble(data['courseAccuracy']),
  );

  static DateTime _timestampFrom(Map<String, dynamic> data) =>
      DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as num).toInt(), isUtc: true).toLocal();

  static double? _nullableDouble(dynamic value) => value == null ? null : (value as num).toDouble();

  @override
  Function get fromJsonFunction => _$WorkoutRouteLocationFromJson;
  factory WorkoutRouteLocation.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<WorkoutRouteLocation>(json);
  @override
  Map<String, dynamic> toJson() => _$WorkoutRouteLocationToJson(this);

  @override
  bool operator ==(Object other) =>
      other is WorkoutRouteLocation &&
      latitude == other.latitude &&
      longitude == other.longitude &&
      timestamp == other.timestamp &&
      altitude == other.altitude &&
      horizontalAccuracy == other.horizontalAccuracy &&
      verticalAccuracy == other.verticalAccuracy &&
      speed == other.speed &&
      course == other.course &&
      speedAccuracy == other.speedAccuracy &&
      courseAccuracy == other.courseAccuracy;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    timestamp,
    altitude,
    horizontalAccuracy,
    verticalAccuracy,
    speed,
    course,
    speedAccuracy,
    courseAccuracy,
  );
}

/// Route data captured for a workout session.
///
/// Parameters:
/// * [locations] - ordered list of [WorkoutRouteLocation] samples.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class WorkoutRouteHealthValue extends HealthValue {
  List<WorkoutRouteLocation> locations;
  String? workoutUuid;

  WorkoutRouteHealthValue({required this.locations, this.workoutUuid});

  factory WorkoutRouteHealthValue.fromHealthDataPoint(dynamic dataPoint) {
    final rawRoute = (dataPoint['route'] as List<dynamic>? ?? [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();

    return WorkoutRouteHealthValue(
      locations: rawRoute.map(WorkoutRouteLocation.fromHealthDataPoint).toList(),
      workoutUuid: dataPoint['workout_uuid'] as String?,
    );
  }

  @override
  Function get fromJsonFunction => _$WorkoutRouteHealthValueFromJson;
  factory WorkoutRouteHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<WorkoutRouteHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$WorkoutRouteHealthValueToJson(this);

  @override
  String toString() => '$runtimeType - locations: ${locations.length} samples, workoutUuid: $workoutUuid';

  @override
  bool operator ==(Object other) =>
      other is WorkoutRouteHealthValue && listEquals(locations, other.locations) && workoutUuid == other.workoutUuid;

  @override
  int get hashCode => Object.hash(Object.hashAll(locations), workoutUuid);
}
