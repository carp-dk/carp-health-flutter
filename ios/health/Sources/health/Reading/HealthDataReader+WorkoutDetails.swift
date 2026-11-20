import HealthKit

extension HealthDataReader {
    private static let metersPerSecond = HKUnit.meter().unitDivided(by: HKUnit.second())
    private static let kilocaloriesPerHourKilogram = HKUnit.kilocalorie().unitDivided(
        by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.hour())
    )

    /// What a workout's map has besides its name and totals (WorkoutHealthValue on the Dart side):
    /// its duration without pauses in seconds, the values of its metadata, its events and, for a
    /// swim, its pool length and laps (swimmingDetails). A value the workout does not have is sent
    /// as null.
    func workoutDetails(of workout: HKWorkout) -> [String: Any] {
        func quantity(_ key: String, in unit: HKUnit) -> Any {
            Self.quantity(workout.metadata, key, in: unit) as Any
        }
        return [
            "duration": workout.duration,
            "avgMets": quantity(HKMetadataKeyAverageMETs, in: Self.kilocaloriesPerHourKilogram),
            "elevationAscended": quantity(HKMetadataKeyElevationAscended, in: .meter()),
            "elevationDescended": quantity(HKMetadataKeyElevationDescended, in: .meter()),
            "indoorWorkout": (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) as Any,
            "weatherTemperature": quantity(HKMetadataKeyWeatherTemperature, in: .degreeCelsius()),
            "weatherHumidity": quantity(HKMetadataKeyWeatherHumidity, in: .percent()),
            "averageSpeed": quantity(HKMetadataKeyAverageSpeed, in: Self.metersPerSecond),
            "maximumSpeed": quantity(HKMetadataKeyMaximumSpeed, in: Self.metersPerSecond),
            "workoutEvents": workout.workoutEvents?.map(Self.workoutEventDictionary) as Any,
            "swimming": Self.swimmingDetails(of: workout) as Any,
        ]
    }

    /// The metadata quantity under key in unit, nil when there is none or it is of another kind:
    /// HealthKit raises an exception (crashing the app) for a unit that cannot express a quantity.
    static func quantity(_ metadata: [String: Any]?, _ key: String, in unit: HKUnit) -> Double? {
        guard let quantity = metadata?[key] as? HKQuantity, quantity.is(compatibleWith: unit) else {
            return nil
        }
        return quantity.doubleValue(for: unit)
    }

    /// The map of a workout event (WorkoutEvent on the Dart side): the name of its type, and its
    /// start and end in milliseconds since the epoch. Only laps and segments last; other events end
    /// when they start.
    static func workoutEventDictionary(_ event: HKWorkoutEvent) -> [String: Any] {
        [
            "type": workoutEventTypeName(event.type),
            "start": Int(event.dateInterval.start.timeIntervalSince1970 * 1000),
            "end": Int(event.dateInterval.end.timeIntervalSince1970 * 1000),
        ]
    }

    /// The name of a workout event type (WorkoutEventType on the Dart side), "unknown" for a type
    /// HealthKit added after this plugin.
    static func workoutEventTypeName(_ type: HKWorkoutEventType) -> String {
        switch type {
        case .pause: return "pause"
        case .resume: return "resume"
        case .lap: return "lap"
        case .marker: return "marker"
        case .motionPaused: return "motionPaused"
        case .motionResumed: return "motionResumed"
        case .segment: return "segment"
        case .pauseOrResumeRequest: return "pauseOrResumeRequest"
        @unknown default: return "unknown"
        }
    }
}
