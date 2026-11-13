import HealthKit

/// The names of workout activity types (HealthWorkoutActivityType on the Dart side) that reads
/// give. Some names write the same HealthKit type: RUNNING_TREADMILL writes running, ROCK_CLIMBING
/// climbing, SWIMMING_OPEN_WATER and SWIMMING_POOL swimming. A workout of such a type reads as the
/// type's general name unless its metadata tells which specific name it was.
struct WorkoutActivityNames {
    /// The name each HealthKit type with several names reads as when the metadata says no more.
    static let generalNames: [HKWorkoutActivityType: String] = [
        .running: "RUNNING",
        .climbing: "CLIMBING",
        .swimming: "SWIMMING",
    ]

    /// The one name of each HealthKit type, before the metadata refines it.
    let canonicalNames: [HKWorkoutActivityType: String]

    /// - Parameter typesByName: The HealthKit type each name writes, as in
    ///   HealthPlugin.workoutActivityTypeMap
    init(_ typesByName: [String: HKWorkoutActivityType]) {
        var names = WorkoutActivityNames.generalNames
        // In name order: a dictionary's order changes with every launch, and reads must not.
        for (name, type) in typesByName.sorted(by: { $0.key < $1.key }) where names[type] == nil {
            names[type] = name
        }
        canonicalNames = names
    }

    /// The name of a workout of [type] with [metadata]: SWIMMING_POOL or SWIMMING_OPEN_WATER for a
    /// swim with HKMetadataKeySwimmingLocationType, RUNNING_TREADMILL for an indoor run and the
    /// type's canonical name otherwise; nil for a type without a name.
    func name(of type: HKWorkoutActivityType, metadata: [String: Any]?) -> String? {
        switch type {
        case .swimming:
            let location = (metadata?[HKMetadataKeySwimmingLocationType] as? NSNumber)
                .flatMap { HKWorkoutSwimmingLocationType(rawValue: $0.intValue) }
            if location == .pool {
                return "SWIMMING_POOL"
            }
            if location == .openWater {
                return "SWIMMING_OPEN_WATER"
            }
        case .running:
            if metadata?[HKMetadataKeyIndoorWorkout] as? Bool == true {
                return "RUNNING_TREADMILL"
            }
        default:
            break
        }
        return canonicalNames[type]
    }

    /// The metadata a workout written as [name] gets for the keys the caller's metadata does not
    /// set, so that it reads as [name] again. SWIMMING_POOL gets none here: HealthKit only accepts
    /// a pool swim with a lap length (HKMetadataKeyLapLength), so a write adds the pool location
    /// with the lap length when it has a pool length (SwimmingWorkout.metadata) and reads as
    /// SWIMMING without one. Nor does ROCK_CLIMBING, which HealthKit has no metadata for.
    static func defaultMetadata(for name: String) -> [String: Any] {
        switch name {
        case "SWIMMING_OPEN_WATER":
            [HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.openWater.rawValue]
        case "RUNNING_TREADMILL":
            [HKMetadataKeyIndoorWorkout: true]
        default:
            [:]
        }
    }
}
