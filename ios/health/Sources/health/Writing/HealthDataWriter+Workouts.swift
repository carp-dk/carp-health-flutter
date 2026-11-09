import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes workout data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeWorkoutData(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
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

        var totalEnergyBurned: HKQuantity?
        var totalDistance: HKQuantity? = nil

        // Handle optional arguments
        if let teb = (arguments["totalEnergyBurned"] as? Double) {
            totalEnergyBurned = HKQuantity(
                unit: unitDict[(arguments["totalEnergyBurnedUnit"] as! String)]!, doubleValue: teb
            )
        }
        if let td = (arguments["totalDistance"] as? Double) {
            totalDistance = HKQuantity(
                unit: unitDict[(arguments["totalDistanceUnit"] as! String)]!, doubleValue: td
            )
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let workout = HKWorkout(
            activityType: activityTypeValue,
            start: dateFrom,
            end: dateTo,
            duration: dateTo.timeIntervalSince(dateFrom),
            totalEnergyBurned: totalEnergyBurned ?? nil,
            totalDistance: totalDistance ?? nil,
            metadata: workoutMetadata(from: arguments["metadata"])
        )

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
        guard let arguments = call.arguments as? NSDictionary,
            let activityType = (arguments["activityType"] as? String),
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber),
            let activityTypeValue = workoutActivityTypeMap[activityType]
        else {
            throw PluginError(
                message: "Invalid Arguments - activityType, startTime or endTime invalid")
        }

        var totalEnergyBurned: HKQuantity?
        var totalDistance: HKQuantity? = nil

        // Handle optional arguments
        if let teb = (arguments["totalEnergyBurned"] as? Double) {
            totalEnergyBurned = HKQuantity(
                unit: unitDict[(arguments["totalEnergyBurnedUnit"] as! String)]!, doubleValue: teb)
        }
        if let td = (arguments["totalDistance"] as? Double) {
            totalDistance = HKQuantity(
                unit: unitDict[(arguments["totalDistanceUnit"] as! String)]!, doubleValue: td)
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let workout = HKWorkout(
            activityType: activityTypeValue,
            start: dateFrom,
            end: dateTo,
            duration: dateTo.timeIntervalSince(dateFrom),
            totalEnergyBurned: totalEnergyBurned ?? nil,
            totalDistance: totalDistance ?? nil,
            metadata: workoutMetadata(from: arguments["metadata"])
        )

        healthStore.save(
            workout,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving Workout. Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    if success {
                        // Return the UUID of the saved object
                        if let savedSample = workout as? HKWorkout {
                            print("Saved: \(savedSample.uuid.uuidString)")
                            result(savedSample.uuid.uuidString) // Return UUID as String
                        } else {
                            result("")
                        }
                    }

                    result("")
                }
            })
    }
}
