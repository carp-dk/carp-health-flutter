import HealthKit

extension HealthDataWriter {
    /// Converts the optional "metadata" argument of writeWorkoutData and writeWorkoutDataUUID
    /// (the map of the Dart WorkoutMetadata class) into HealthKit workout metadata.
    /// syncIdentifier and syncVersion are ignored unless both are given.
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
