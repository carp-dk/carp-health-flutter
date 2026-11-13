import HealthKit

extension HealthDataReader {
    /// The map of a swim's pool length and laps (SwimmingDetails on the Dart side), nil for a
    /// workout of another type and for a swim that has neither: poolLength, the workout's
    /// HKMetadataKeyLapLength in meters (null without one: HealthKit has it for pool swims only),
    /// and laps, the workout's lap events (swimmingLapDictionary) by their start. Its other events,
    /// such as the segments of the sets of a swim, are only in its workoutEvents.
    static func swimmingDetails(of workout: HKWorkout) -> [String: Any]? {
        guard workout.workoutActivityType == .swimming else { return nil }
        let poolLength = quantity(workout.metadata, HKMetadataKeyLapLength, in: .meter())
        let laps = (workout.workoutEvents ?? [])
            .filter { $0.type == .lap }
            .sorted { $0.dateInterval.start < $1.dateInterval.start }
            .map(swimmingLapDictionary)
        guard poolLength != nil || !laps.isEmpty else { return nil }
        return ["poolLength": poolLength as Any, "laps": laps]
    }

    /// The map of a lap of a swim (SwimmingLap on the Dart side): its startTime and endTime in
    /// milliseconds since the epoch and strokeStyle, the name of its HKMetadataKeySwimmingStrokeStyle
    /// (SwimmingStrokeStyles), unknown for a lap without one. The laps Apple Watch recorded before
    /// watchOS 4 end when they start.
    static func swimmingLapDictionary(_ lap: HKWorkoutEvent) -> [String: Any] {
        let style = (lap.metadata?[HKMetadataKeySwimmingStrokeStyle] as? NSNumber)
            .flatMap { HKSwimmingStrokeStyle(rawValue: $0.intValue) }
        return [
            "startTime": Int(lap.dateInterval.start.timeIntervalSince1970 * 1000),
            "endTime": Int(lap.dateInterval.end.timeIntervalSince1970 * 1000),
            "strokeStyle": SwimmingStrokeStyles.name(of: style ?? .unknown),
        ]
    }

    /// The total number of swimming strokes of [workout], nil when it has none: its statistics from
    /// iOS 16 on, which replace the totalSwimmingStrokeCount property that iOS 18 deprecates, and
    /// that property before.
    static func totalSwimmingStrokeCount(of workout: HKWorkout) -> Double? {
        if #available(iOS 16.0, *) {
            return workout.statistics(for: HKQuantityType(.swimmingStrokeCount))?.sumQuantity()?
                .doubleValue(for: .count())
        }
        return workout.totalSwimmingStrokeCount?.doubleValue(for: .count())
    }
}
