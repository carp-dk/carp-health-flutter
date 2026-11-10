import HealthKit

extension HealthDataWriter {
    /// Converts the optional "metadata" argument of writeWorkoutData and writeWorkoutDataUUID
    /// (the map of the Dart WorkoutMetadata class) into HealthKit workout metadata.
    /// appleFitnessPlusSession is ignored before iOS 17, where HealthKit has no key for it, and
    /// syncIdentifier and syncVersion unless both are given.
    /// - Parameters:
    ///   - argument: The "metadata" argument, missing when the caller set no metadata
    ///   - defaults: Metadata kept for the keys the caller did not set
    /// - Returns: The workout metadata, or nil when it is empty
    func workoutMetadata(from argument: Any?, defaults: [String: Any] = [:]) -> [String: Any]? {
        let values = argument as? [String: Any]
        var metadata = defaults

        if let workoutBrandName = values?["workoutBrandName"] as? String {
            metadata[HKMetadataKeyWorkoutBrandName] = workoutBrandName
        }
        if let indoorWorkout = values?["indoorWorkout"] as? Bool {
            metadata[HKMetadataKeyIndoorWorkout] = indoorWorkout
        }
        if let groupFitness = values?["groupFitness"] as? Bool {
            metadata[HKMetadataKeyGroupFitness] = groupFitness
        }
        if let coachedWorkout = values?["coachedWorkout"] as? Bool {
            metadata[HKMetadataKeyCoachedWorkout] = coachedWorkout
        }
        if #available(iOS 17.0, *),
           let appleFitnessPlusSession = values?["appleFitnessPlusSession"] as? Bool
        {
            metadata[HKMetadataKeyAppleFitnessPlusSession] = appleFitnessPlusSession
        }
        // HealthKit raises an exception (crashing the app) for one of these without the other.
        if let syncIdentifier = values?["syncIdentifier"] as? String,
           let syncVersion = values?["syncVersion"] as? Int
        {
            metadata[HKMetadataKeySyncIdentifier] = syncIdentifier
            metadata[HKMetadataKeySyncVersion] = syncVersion
        }

        return metadata.isEmpty ? nil : metadata
    }
}
