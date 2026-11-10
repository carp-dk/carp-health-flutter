part of '../../health.dart';

/// HealthKit metadata of a workout written with [Health.writeWorkoutData] or
/// [Health.writeWorkoutDataUUID].
///
/// iOS only: each field that is set is saved on the workout under the
/// HealthKit metadata key named in its documentation, and a field left null
/// is not saved. Health Connect has no such metadata, so it is ignored on
/// Android. [appleFitnessPlusSession] needs iOS 17 or later. [syncIdentifier]
/// and [syncVersion] are set together or not at all.
///
/// See https://developer.apple.com/documentation/healthkit/workout-metadata-keys
class WorkoutMetadata {
  /// The brand name of the workout, for example the fitness service or
  /// program it is from. iOS only, ignored on Android. Maps to HealthKit's
  /// `HKMetadataKeyWorkoutBrandName`.
  final String? workoutBrandName;

  /// Whether the workout was done indoors (true) or outdoors (false). iOS
  /// only, ignored on Android. Maps to HealthKit's `HKMetadataKeyIndoorWorkout`.
  final bool? indoorWorkout;

  /// Whether the workout was part of a group fitness class. iOS only, ignored
  /// on Android. Maps to HealthKit's `HKMetadataKeyGroupFitness`.
  final bool? groupFitness;

  /// Whether the workout was done with a coach or personal trainer. iOS only,
  /// ignored on Android. Maps to HealthKit's `HKMetadataKeyCoachedWorkout`.
  final bool? coachedWorkout;

  /// Whether the workout was an Apple Fitness+ session. iOS 17 and later
  /// only: ignored on earlier iOS versions and on Android. Maps to HealthKit's
  /// `HKMetadataKeyAppleFitnessPlusSession`.
  final bool? appleFitnessPlusSession;

  /// Your id of the workout, to write it again without adding a copy: a
  /// workout written with the [syncIdentifier] of a workout this app wrote
  /// before replaces that workout if its [syncVersion] is greater. iOS only,
  /// ignored on Android, where the workout writes take a `clientRecordId` and
  /// `clientRecordVersion` instead. Maps to HealthKit's
  /// `HKMetadataKeySyncIdentifier`.
  final String? syncIdentifier;

  /// The version of the workout with [syncIdentifier]. iOS only, ignored on
  /// Android. Maps to HealthKit's `HKMetadataKeySyncVersion`.
  final int? syncVersion;

  /// Create the metadata of a workout. Fields left null are not saved.
  const WorkoutMetadata({
    this.workoutBrandName,
    this.indoorWorkout,
    this.groupFitness,
    this.coachedWorkout,
    this.appleFitnessPlusSession,
    this.syncIdentifier,
    this.syncVersion,
  });

  /// The fields that are set, by field name. This is the `metadata` argument
  /// the workout writes send to the platform.
  Map<String, dynamic> toJson() => {
    if (workoutBrandName != null) 'workoutBrandName': workoutBrandName,
    if (indoorWorkout != null) 'indoorWorkout': indoorWorkout,
    if (groupFitness != null) 'groupFitness': groupFitness,
    if (coachedWorkout != null) 'coachedWorkout': coachedWorkout,
    if (appleFitnessPlusSession != null) 'appleFitnessPlusSession': appleFitnessPlusSession,
    if (syncIdentifier != null) 'syncIdentifier': syncIdentifier,
    if (syncVersion != null) 'syncVersion': syncVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkoutMetadata &&
      workoutBrandName == other.workoutBrandName &&
      indoorWorkout == other.indoorWorkout &&
      groupFitness == other.groupFitness &&
      coachedWorkout == other.coachedWorkout &&
      appleFitnessPlusSession == other.appleFitnessPlusSession &&
      syncIdentifier == other.syncIdentifier &&
      syncVersion == other.syncVersion;

  @override
  int get hashCode => Object.hash(
    workoutBrandName,
    indoorWorkout,
    groupFitness,
    coachedWorkout,
    appleFitnessPlusSession,
    syncIdentifier,
    syncVersion,
  );

  @override
  String toString() =>
      '$runtimeType - workoutBrandName: $workoutBrandName, indoorWorkout: $indoorWorkout, '
      'groupFitness: $groupFitness, coachedWorkout: $coachedWorkout, '
      'appleFitnessPlusSession: $appleFitnessPlusSession, '
      'syncIdentifier: $syncIdentifier, syncVersion: $syncVersion';
}
