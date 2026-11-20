import HealthKit

/// What a workout write saves about a swim: its pool length and laps (the swimming argument,
/// SwimmingDetails on the Dart side) and its total number of strokes (totalSwimmingStrokeCount).
/// Each is optional; a workout of another type has none.
struct SwimmingWorkout {
    /// The length of the pool in meters, saved as the workout's HKMetadataKeyLapLength.
    let poolLength: Double?
    /// The laps, saved as the workout's lap events, each with its HKMetadataKeySwimmingStrokeStyle.
    let laps: [HKWorkoutEvent]
    /// The total number of strokes, saved as the workout's totalSwimmingStrokeCount.
    let totalStrokeCount: HKQuantity?

    /// The metadata of the swim: the pool location (HKMetadataKeySwimmingLocationType) and the lap
    /// length for a pool length, none without one. HealthKit raises an exception (crashing the app)
    /// for a pool swim without a lap length and for a lap length without the pool location, so a
    /// pool swim written without a pool length is saved without a location and reads as SWIMMING.
    var metadata: [String: Any] {
        guard let poolLength else { return [:] }
        return [
            HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.pool.rawValue,
            HKMetadataKeyLapLength: HKQuantity(unit: .meter(), doubleValue: poolLength),
        ]
    }
}

extension HealthDataWriter {
    /// The swim of a writeWorkoutData or writeWorkoutDataUUID call, from its optional arguments
    /// swimming, a map of poolLength (meters) and laps (maps of startTime and endTime in
    /// milliseconds since the epoch and strokeStyle, the name of a stroke style), and
    /// totalSwimmingStrokeCount. Missing and null arguments are left out.
    ///
    /// Checks what HealthKit raises an exception for (crashing the app) when it creates the
    /// workout: a lap length without the pool location, which only SWIMMING_POOL gets, a lap
    /// length of 0 m or less, a lap outside the workout and a stroke style it does not have. The
    /// pool length must be at most 1000 m, as on the Dart side, which also checks that the laps
    /// are in order and do not overlap (HealthKit sorts them and takes overlapping laps).
    /// - Parameters:
    ///   - arguments: The arguments of the call
    ///   - activityType: The name of the workout's type, e.g. SWIMMING_POOL
    ///   - start: The start of the workout
    ///   - end: The end of the workout
    /// - Throws: PluginError for a swim HealthKit does not take or arguments of another shape
    func swimmingWorkout(
        from arguments: NSDictionary, activityType: String, start: Date, end: Date
    ) throws -> SwimmingWorkout {
        let totalStrokeCount = (arguments["totalSwimmingStrokeCount"] as? Double).map {
            HKQuantity(unit: .count(), doubleValue: $0)
        }
        let shape = "swimming must be a map of poolLength and laps"
        guard let swimming: NSDictionary = try optionalArgument(arguments["swimming"], or: shape) else {
            return SwimmingWorkout(poolLength: nil, laps: [], totalStrokeCount: totalStrokeCount)
        }
        let poolLength: Double? = try optionalArgument(swimming["poolLength"], or: shape)
        let lapArguments: [Any] = try optionalArgument(swimming["laps"], or: shape) ?? []

        if let poolLength {
            guard activityType == "SWIMMING_POOL" else {
                throw PluginError(message: "poolLength can only be given for SWIMMING_POOL")
            }
            // Also false for NaN.
            guard poolLength > 0, poolLength <= 1000 else {
                throw PluginError(message: "poolLength must be more than 0 and at most 1000 meters")
            }
        }
        let laps = try lapArguments.map { try swimmingLap(from: $0, workoutStart: start, workoutEnd: end) }
        return SwimmingWorkout(poolLength: poolLength, laps: laps, totalStrokeCount: totalStrokeCount)
    }

    /// The lap event of a lap of a swim: a map of startTime and endTime (milliseconds since the
    /// epoch) and strokeStyle, saved as its HKMetadataKeySwimmingStrokeStyle (SwimmingStrokeStyles).
    /// A lap may last no time, as the laps Apple Watch recorded before watchOS 4 do.
    /// - Throws: PluginError for a lap that is no such map, has a style that is no stroke style,
    ///   ends before it starts (DateInterval stops the app for that) or lies outside the workout
    func swimmingLap(from argument: Any, workoutStart: Date, workoutEnd: Date) throws -> HKWorkoutEvent {
        guard let lap = argument as? NSDictionary,
              let startTime = lap["startTime"] as? NSNumber,
              let endTime = lap["endTime"] as? NSNumber,
              let styleName = lap["strokeStyle"] as? String
        else {
            throw PluginError(message: "A lap must be a map of startTime, endTime and strokeStyle")
        }
        guard let style = SwimmingStrokeStyles.style(named: styleName) else {
            throw PluginError(message: "\(styleName) is not a swimming stroke style")
        }
        let lapStart = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let lapEnd = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)
        guard lapStart <= lapEnd else {
            throw PluginError(message: "A lap's startTime must be equal to or earlier than its endTime")
        }
        guard lapStart >= workoutStart, lapEnd <= workoutEnd else {
            throw PluginError(message: "A lap must start and end within the workout")
        }
        return HKWorkoutEvent(
            type: .lap, dateInterval: DateInterval(start: lapStart, end: lapEnd),
            metadata: [HKMetadataKeySwimmingStrokeStyle: style.rawValue]
        )
    }

    /// [value] as a T, nil when it is missing or null (NSNull here).
    /// - Throws: PluginError with [message] for a value of another type
    private func optionalArgument<T>(_ value: Any?, or message: String) throws -> T? {
        guard let value, !(value is NSNull) else { return nil }
        guard let typed = value as? T else {
            throw PluginError(message: message)
        }
        return typed
    }
}
