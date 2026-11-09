import HealthKit

/// Class responsible for writing health data to HealthKit
class HealthDataWriter {
    let healthStore: HKHealthStore
    let dataTypesDict: [String: HKSampleType]
    let unitDict: [String: HKUnit]
    let workoutActivityTypeMap: [String: HKWorkoutActivityType]
    private var workoutRouteBuilders: [String: HKWorkoutRouteBuilder] = [:]
    private let workoutRouteBuildersQueue = DispatchQueue(
        label: "com.carp.health.workoutRouteBuilders"
    )
    /// Parses route location timestamps sent as ISO 8601 strings.
    lazy var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// - Parameters:
    ///   - healthStore: The HealthKit store
    ///   - dataTypesDict: Dictionary of data types
    ///   - unitDict: Dictionary of units
    ///   - workoutActivityTypeMap: Dictionary of workout activity types
    init(
        healthStore: HKHealthStore, dataTypesDict: [String: HKSampleType],
        unitDict: [String: HKUnit], workoutActivityTypeMap: [String: HKWorkoutActivityType]
    ) {
        self.healthStore = healthStore
        self.dataTypesDict = dataTypesDict
        self.unitDict = unitDict
        self.workoutActivityTypeMap = workoutActivityTypeMap
    }

    // MARK: - Workout Route Helpers

    // workoutRouteBuilders is only touched on workoutRouteBuildersQueue. Its accessors stay in
    // this file so the dictionary itself can stay private.
    func storeWorkoutRouteBuilder(
        _ builder: HKWorkoutRouteBuilder,
        for identifier: String
    ) {
        workoutRouteBuildersQueue.async {
            self.workoutRouteBuilders[identifier] = builder
        }
    }

    func workoutRouteBuilder(for identifier: String) -> HKWorkoutRouteBuilder? {
        var builder: HKWorkoutRouteBuilder?
        workoutRouteBuildersQueue.sync {
            builder = self.workoutRouteBuilders[identifier]
        }
        return builder
    }

    func removeWorkoutRouteBuilder(for identifier: String) -> HKWorkoutRouteBuilder? {
        var builder: HKWorkoutRouteBuilder?
        workoutRouteBuildersQueue.sync {
            builder = self.workoutRouteBuilders.removeValue(forKey: identifier)
        }
        return builder
    }
}
