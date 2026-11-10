import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes workout data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeWorkoutData(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let workout = try workout(from: call, result: result) else { return }

        healthStore.save(
            workout,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Workout. Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }

    /// Writes workout data and return UUID on success, otherwise an empty string
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeWorkoutDataUUID(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let workout = try workout(from: call, result: result) else { return }

        healthStore.save(
            workout,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Workout. Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    // The UUID of the saved workout, an empty string if it was not saved
                    result(success ? workout.uuid.uuidString : "")
                }
            }
        )
    }

    /// The workout writeWorkoutData and writeWorkoutDataUUID save, or nil after replying an
    /// INVALID_ARGUMENT error for a time range or total that HKWorkout does not accept (it raises
    /// an exception for those, crashing the app).
    /// - Throws: PluginError when activityType, startTime or endTime is missing or unknown
    private func workout(from call: FlutterMethodCall, result: @escaping FlutterResult) throws -> HKWorkout? {
        guard let arguments = call.arguments as? NSDictionary,
              let activityType = (arguments["activityType"] as? String),
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber),
              let activityTypeValue = workoutActivityTypeMap[activityType]
        else {
            throw PluginError(
                message: "Invalid Arguments - activityType, startTime or endTime invalid"
            )
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let totalEnergyBurned: HKQuantity?
        let totalDistance: HKQuantity?
        do {
            try checkSampleDates(start: dateFrom, end: dateTo, of: HKObjectType.workoutType())
            totalEnergyBurned = try workoutTotal(
                arguments, valueKey: "totalEnergyBurned", unitKey: "totalEnergyBurnedUnit",
                compatibleWith: HKUnit.kilocalorie()
            )
            totalDistance = try workoutTotal(
                arguments, valueKey: "totalDistance", unitKey: "totalDistanceUnit",
                compatibleWith: HKUnit.meter()
            )
        } catch {
            let message = (error as? PluginError)?.message ?? error.localizedDescription
            result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
            return nil
        }

        return HKWorkout(
            activityType: activityTypeValue,
            start: dateFrom,
            end: dateTo,
            duration: dateTo.timeIntervalSince(dateFrom),
            totalEnergyBurned: totalEnergyBurned,
            totalDistance: totalDistance,
            metadata: workoutMetadata(from: arguments["metadata"])
        )
    }

    /// The optional total energy or distance of a workout, in the unit its unit argument names.
    /// - Parameters:
    ///   - arguments: The arguments of the call
    ///   - valueKey: The argument holding the total, missing when the caller set none
    ///   - unitKey: The argument holding the name of the total's unit
    ///   - baseUnit: A unit of the kind (energy or length) the total must be in
    /// - Throws: PluginError when the unit is missing, unknown or of another kind
    func workoutTotal(
        _ arguments: NSDictionary, valueKey: String, unitKey: String, compatibleWith baseUnit: HKUnit
    ) throws -> HKQuantity? {
        guard let value = arguments[valueKey] as? Double else { return nil }
        guard let unitName = arguments[unitKey] as? String, let unit = unitDict[unitName] else {
            throw PluginError(message: "Argument \(unitKey) must name a unit that is available on iOS")
        }
        let total = HKQuantity(unit: unit, doubleValue: value)
        guard total.is(compatibleWith: baseUnit) else {
            throw PluginError(message: "Unit \(unitName) cannot be used for \(valueKey)")
        }
        return total
    }
}
