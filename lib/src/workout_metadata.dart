part of '../health.dart';

/// Metadata for workout data.
///
/// All fields are optional and iOS-only. These fields are ignored on Android
/// as Health Connect does not support workout metadata.
///
/// See Apple's HealthKit documentation for more details:
/// https://developer.apple.com/documentation/healthkit/hkmetadatakey
class WorkoutMetadata {
  /// The activity type of the workout (e.g., "Running", "Cycling").
  /// Maps to HKMetadataKeyActivityType.
  /// **Requires iOS 17.0 or later.**
  final String? activityType;

  /// Whether this workout is part of an Apple Fitness+ session.
  /// Maps to HKMetadataKeyAppleFitnessPlusSession.
  /// **Requires iOS 17.0 or later.**
  final bool? appleFitnessPlusSession;

  /// Whether this workout was coached.
  /// Maps to HKMetadataKeyCoachedWorkout.
  final bool? coachedWorkout;

  /// Whether this workout was done in a group fitness setting.
  /// Maps to HKMetadataKeyGroupFitness.
  final bool? groupFitness;

  /// Whether this workout was done indoors.
  /// Maps to HKMetadataKeyIndoorWorkout.
  final bool? indoorWorkout;

  /// The brand name associated with the workout (e.g., "Peloton", "Nike Run Club").
  /// Maps to HKMetadataKeyWorkoutBrandName.
  final String? workoutBrandName;

  /// Creates a [WorkoutMetadata] instance.
  ///
  /// All parameters are optional and iOS-only.
  const WorkoutMetadata({
    this.activityType,
    this.appleFitnessPlusSession,
    this.coachedWorkout,
    this.groupFitness,
    this.indoorWorkout,
    this.workoutBrandName,
  });

  /// Converts this [WorkoutMetadata] to a JSON map.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (activityType != null) map['activityType'] = activityType;
    if (appleFitnessPlusSession != null) {
      map['appleFitnessPlusSession'] = appleFitnessPlusSession;
    }
    if (coachedWorkout != null) map['coachedWorkout'] = coachedWorkout;
    if (groupFitness != null) map['groupFitness'] = groupFitness;
    if (indoorWorkout != null) map['indoorWorkout'] = indoorWorkout;
    if (workoutBrandName != null) map['workoutBrandName'] = workoutBrandName;
    return map;
  }

  @override
  String toString() =>
      'WorkoutMetadata('
      'activityType: $activityType, '
      'appleFitnessPlusSession: $appleFitnessPlusSession, '
      'coachedWorkout: $coachedWorkout, '
      'groupFitness: $groupFitness, '
      'indoorWorkout: $indoorWorkout, '
      'workoutBrandName: $workoutBrandName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutMetadata &&
          runtimeType == other.runtimeType &&
          activityType == other.activityType &&
          appleFitnessPlusSession == other.appleFitnessPlusSession &&
          coachedWorkout == other.coachedWorkout &&
          groupFitness == other.groupFitness &&
          indoorWorkout == other.indoorWorkout &&
          workoutBrandName == other.workoutBrandName;

  @override
  int get hashCode =>
      activityType.hashCode ^
      appleFitnessPlusSession.hashCode ^
      coachedWorkout.hashCode ^
      groupFitness.hashCode ^
      indoorWorkout.hashCode ^
      workoutBrandName.hashCode;
}
