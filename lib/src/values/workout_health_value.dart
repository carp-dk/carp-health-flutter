part of '../../health.dart';

/// A [HealthValue] object for workouts
///
/// Parameters:
/// * [workoutActivityType] - the type of workout
/// * [totalEnergyBurned] - the total energy burned during the workout
/// * [totalEnergyBurnedUnit] - the unit of the total energy burned
/// * [totalDistance] - the total distance of the workout
/// * [totalDistanceUnit] - the unit of the total distance
/// * [totalSteps] - the total steps of the workout
/// * [totalStepsUnit] - the unit of the total steps
/// * [totalFlightsClimbed] - the flights of stairs climbed during the workout (iOS only)
/// * [totalSwimmingStrokeCount] - the swimming strokes of the workout (iOS only)
/// * [swimming] - the pool length and laps of a swimming workout
/// * [duration], [avgMets], [elevationAscended], [elevationDescended],
///   [indoorWorkout], [weatherTemperature], [weatherHumidity], [averageSpeed],
///   [maximumSpeed] and [workoutEvents] - what HealthKit records about the
///   workout besides its totals (iOS only, null on Android)
///
/// On Android, [totalDistance], [totalEnergyBurned] and [totalSteps] count the Health Connect
/// records that the app which wrote the workout recorded in its time, so an activity that two apps
/// recorded (for example a watch app and the phone) does not count twice. Such a total is `null`
/// when that app wrote no such records, or without permission to read them: `READ_DISTANCE`
/// ([HealthDataType.DISTANCE_DELTA]) for [totalDistance], `READ_TOTAL_CALORIES_BURNED`
/// ([HealthDataType.TOTAL_CALORIES_BURNED]) for [totalEnergyBurned] and `READ_STEPS`
/// ([HealthDataType.STEPS]) for [totalSteps]. Read those types over the workout's time to count the
/// data of other apps too.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class WorkoutHealthValue extends HealthValue {
  /// The type of the workout.
  HealthWorkoutActivityType workoutActivityType;

  /// The total energy burned during the workout.
  /// Might not be available for all workouts.
  int? totalEnergyBurned;

  /// The unit of the total energy burned during the workout.
  /// Might not be available for all workouts.
  HealthDataUnit? totalEnergyBurnedUnit;

  /// The total distance covered during the workout.
  /// Might not be available for all workouts.
  int? totalDistance;

  /// The unit of the total distance covered during the workout.
  /// Might not be available for all workouts.
  HealthDataUnit? totalDistanceUnit;

  /// The total steps covered during the workout.
  /// Might not be available for all workouts.
  int? totalSteps;

  /// The unit of the total steps covered during the workout.
  /// Might not be available for all workouts.
  HealthDataUnit? totalStepsUnit;

  /// The total number of flights of stairs climbed during the workout: HealthKit's total for the
  /// workout, `null` when it has none. iOS only, always `null` on Android.
  int? totalFlightsClimbed;

  /// The total number of swimming strokes during the workout: HealthKit's total for the workout,
  /// `null` when it has none, as written by the `totalSwimmingStrokeCount` of [Health.writeWorkoutData].
  /// iOS only, always `null` on Android.
  int? totalSwimmingStrokeCount;

  /// The pool length and laps of a swimming workout, see [SwimmingDetails]: `null` for other workouts, and for a
  /// swim with neither a known pool length nor laps. iOS reads them for HealthKit swims (the lap length and the lap
  /// events of the workout), and Android for Health Connect pool and open water swims (the laps of the session and
  /// the swimming segments over them).
  SwimmingDetails? swimming;

  /// The average intensity of the workout in METs (metabolic equivalents),
  /// in kilocalories per kilogram of body weight per hour (iOS only).
  /// Might not be available for all workouts.
  num? avgMets;

  /// The elevation the workout climbed, in meters (iOS only).
  /// Might not be available for all workouts.
  num? elevationAscended;

  /// The elevation the workout descended, in meters (iOS only).
  /// Might not be available for all workouts.
  num? elevationDescended;

  /// How long the workout was active, in seconds: its time without pauses
  /// (iOS only).
  num? duration;

  /// Whether the workout was indoors (iOS only): HealthKit's
  /// `HKMetadataKeyIndoorWorkout`, which [WorkoutMetadata.indoorWorkout]
  /// writes. Might not be available for all workouts.
  bool? indoorWorkout;

  /// The temperature during the workout, in degrees Celsius (iOS only).
  /// Might not be available for all workouts.
  num? weatherTemperature;

  /// The humidity during the workout (iOS only): HealthKit's
  /// `HKMetadataKeyWeatherHumidity` as a fraction (`HKUnit.percent()`): 0.55
  /// is 55 %.
  /// Might not be available for all workouts.
  num? weatherHumidity;

  /// The average speed of the workout, in meters per second (iOS only).
  /// Might not be available for all workouts.
  num? averageSpeed;

  /// The highest speed of the workout, in meters per second (iOS only).
  /// Might not be available for all workouts.
  num? maximumSpeed;

  /// The events of the workout, such as its pauses, laps and segments (iOS
  /// only).
  List<WorkoutEvent>? workoutEvents;

  WorkoutHealthValue({
    required this.workoutActivityType,
    this.totalEnergyBurned,
    this.totalEnergyBurnedUnit,
    this.totalDistance,
    this.totalDistanceUnit,
    this.totalSteps,
    this.totalStepsUnit,
    this.totalFlightsClimbed,
    this.totalSwimmingStrokeCount,
    this.swimming,
    this.avgMets,
    this.elevationAscended,
    this.elevationDescended,
    this.duration,
    this.indoorWorkout,
    this.weatherTemperature,
    this.weatherHumidity,
    this.averageSpeed,
    this.maximumSpeed,
    this.workoutEvents,
  });

  /// Create a [WorkoutHealthValue] based on a health data point from native data format.
  factory WorkoutHealthValue.fromHealthDataPoint(dynamic dataPoint) => WorkoutHealthValue(
    workoutActivityType: HealthWorkoutActivityType.values.firstWhere(
      (element) => element.name == dataPoint['workoutActivityType'],
      orElse: () => HealthWorkoutActivityType.OTHER,
    ),
    totalEnergyBurned: dataPoint['totalEnergyBurned'] != null ? (dataPoint['totalEnergyBurned'] as num).toInt() : null,
    totalEnergyBurnedUnit: dataPoint['totalEnergyBurnedUnit'] != null
        ? HealthDataUnit.values.firstWhere((element) => element.name == dataPoint['totalEnergyBurnedUnit'])
        : null,
    totalDistance: dataPoint['totalDistance'] != null ? (dataPoint['totalDistance'] as num).toInt() : null,
    totalDistanceUnit: dataPoint['totalDistanceUnit'] != null
        ? HealthDataUnit.values.firstWhere((element) => element.name == dataPoint['totalDistanceUnit'])
        : null,
    totalSteps: dataPoint['totalSteps'] != null ? (dataPoint['totalSteps'] as num).toInt() : null,
    totalStepsUnit: dataPoint['totalStepsUnit'] != null
        ? HealthDataUnit.values.firstWhere((element) => element.name == dataPoint['totalStepsUnit'])
        : null,
    totalFlightsClimbed: dataPoint['totalFlightsClimbed'] != null
        ? (dataPoint['totalFlightsClimbed'] as num).toInt()
        : null,
    totalSwimmingStrokeCount: dataPoint['totalSwimmingStrokeCount'] != null
        ? (dataPoint['totalSwimmingStrokeCount'] as num).toInt()
        : null,
    swimming: SwimmingDetails._ofWorkout(dataPoint['swimming']),
    avgMets: dataPoint['avgMets'] as num?,
    elevationAscended: dataPoint['elevationAscended'] as num?,
    elevationDescended: dataPoint['elevationDescended'] as num?,
    duration: dataPoint['duration'] as num?,
    indoorWorkout: dataPoint['indoorWorkout'] as bool?,
    weatherTemperature: dataPoint['weatherTemperature'] as num?,
    weatherHumidity: dataPoint['weatherHumidity'] as num?,
    averageSpeed: dataPoint['averageSpeed'] as num?,
    maximumSpeed: dataPoint['maximumSpeed'] as num?,
    workoutEvents: (dataPoint['workoutEvents'] as List<dynamic>?)
        ?.map((event) => WorkoutEvent.fromHealthDataPoint(Map<String, dynamic>.from(event as Map)))
        .toList(),
  );

  @override
  Function get fromJsonFunction => _$WorkoutHealthValueFromJson;
  factory WorkoutHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<WorkoutHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$WorkoutHealthValueToJson(this);

  @override
  String toString() =>
      """$runtimeType - workoutActivityType: ${workoutActivityType.name},
           totalEnergyBurned: $totalEnergyBurned,
           totalEnergyBurnedUnit: ${totalEnergyBurnedUnit?.name},
           totalDistance: $totalDistance,
           totalDistanceUnit: ${totalDistanceUnit?.name}
           totalSteps: $totalSteps,
           totalStepsUnit: ${totalStepsUnit?.name},
           totalFlightsClimbed: $totalFlightsClimbed,
           totalSwimmingStrokeCount: $totalSwimmingStrokeCount,
           swimming: $swimming,
           avgMets: $avgMets,
           elevationAscended: $elevationAscended,
           elevationDescended: $elevationDescended,
           duration: $duration,
           indoorWorkout: $indoorWorkout,
           weatherTemperature: $weatherTemperature,
           weatherHumidity: $weatherHumidity,
           averageSpeed: $averageSpeed,
           maximumSpeed: $maximumSpeed,
           workoutEvents: ${workoutEvents?.length} events""";

  @override
  bool operator ==(Object other) =>
      other is WorkoutHealthValue &&
      workoutActivityType == other.workoutActivityType &&
      totalEnergyBurned == other.totalEnergyBurned &&
      totalEnergyBurnedUnit == other.totalEnergyBurnedUnit &&
      totalDistance == other.totalDistance &&
      totalDistanceUnit == other.totalDistanceUnit &&
      totalSteps == other.totalSteps &&
      totalStepsUnit == other.totalStepsUnit &&
      totalFlightsClimbed == other.totalFlightsClimbed &&
      totalSwimmingStrokeCount == other.totalSwimmingStrokeCount &&
      swimming == other.swimming &&
      avgMets == other.avgMets &&
      elevationAscended == other.elevationAscended &&
      elevationDescended == other.elevationDescended &&
      duration == other.duration &&
      indoorWorkout == other.indoorWorkout &&
      weatherTemperature == other.weatherTemperature &&
      weatherHumidity == other.weatherHumidity &&
      averageSpeed == other.averageSpeed &&
      maximumSpeed == other.maximumSpeed &&
      listEquals(workoutEvents, other.workoutEvents);

  @override
  int get hashCode => Object.hash(
    workoutActivityType,
    totalEnergyBurned,
    totalEnergyBurnedUnit,
    totalDistance,
    totalDistanceUnit,
    totalSteps,
    totalStepsUnit,
    totalFlightsClimbed,
    totalSwimmingStrokeCount,
    swimming,
    avgMets,
    elevationAscended,
    elevationDescended,
    duration,
    indoorWorkout,
    weatherTemperature,
    weatherHumidity,
    averageSpeed,
    maximumSpeed,
    workoutEvents == null ? null : Object.hashAll(workoutEvents!),
  );
}
