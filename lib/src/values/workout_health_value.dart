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
  /// `null` when it has none. iOS only, always `null` on Android.
  int? totalSwimmingStrokeCount;

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
           totalSwimmingStrokeCount: $totalSwimmingStrokeCount""";

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
      totalSwimmingStrokeCount == other.totalSwimmingStrokeCount;

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
  );
}
