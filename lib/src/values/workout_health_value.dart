part of '../../health.dart';

/// A [HealthValue] object for workouts
///
/// Parameters:
/// * [workoutActivityType] - the type of workout
/// * [totalEnergyBurned] - the total energy burned during the workout
/// * [totalEnergyBurnedUnit] - the unit of the total energy burned
/// * [totalDistance] - the total distance of the workout
/// * [totalDistanceUnit] - the unit of the total distance
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

  WorkoutHealthValue({
    required this.workoutActivityType,
    this.totalEnergyBurned,
    this.totalEnergyBurnedUnit,
    this.totalDistance,
    this.totalDistanceUnit,
    this.totalSteps,
    this.totalStepsUnit,
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
           totalStepsUnit: ${totalStepsUnit?.name}""";

  @override
  bool operator ==(Object other) =>
      other is WorkoutHealthValue &&
      workoutActivityType == other.workoutActivityType &&
      totalEnergyBurned == other.totalEnergyBurned &&
      totalEnergyBurnedUnit == other.totalEnergyBurnedUnit &&
      totalDistance == other.totalDistance &&
      totalDistanceUnit == other.totalDistanceUnit &&
      totalSteps == other.totalSteps &&
      totalStepsUnit == other.totalStepsUnit;

  @override
  int get hashCode => Object.hash(
    workoutActivityType,
    totalEnergyBurned,
    totalEnergyBurnedUnit,
    totalDistance,
    totalDistanceUnit,
    totalSteps,
    totalStepsUnit,
  );
}
