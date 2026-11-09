import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes blood pressure data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeBloodPressure(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let systolic = (arguments["systolic"] as? Double),
              let diastolic = (arguments["diastolic"] as? Double),
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber),
              let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(message: "Invalid Arguments")
        }
        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
        ]

        let systolic_sample = HKQuantitySample(
            type: HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            quantity: HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: systolic),
            start: dateFrom, end: dateTo, metadata: metadata
        )
        let diastolic_sample = HKQuantitySample(
            type: HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            quantity: HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: diastolic),
            start: dateFrom, end: dateTo, metadata: metadata
        )
        let bpCorrelationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!
        let bpCorrelation = Set(arrayLiteral: systolic_sample, diastolic_sample)
        let blood_pressure_sample = HKCorrelation(
            type: bpCorrelationType, start: dateFrom, end: dateTo, objects: bpCorrelation
        )

        healthStore.save(
            [blood_pressure_sample],
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Blood Pressure Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }

    /// Writes meal nutrition data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeMeal(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let name = (arguments["name"] as? String?),
              let startTime = (arguments["start_time"] as? NSNumber),
              let endTime = (arguments["end_time"] as? NSNumber),
              let mealType = (arguments["meal_type"] as? String?),
              let recordingMethod = arguments["recordingMethod"] as? Int
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let mealTypeString = mealType ?? "UNKNOWN"

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue

        var metadata =
            [
                "HKFoodMeal": mealTypeString,
                HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
            ] as [String: Any]
        if name != nil {
            metadata[HKMetadataKeyFoodType] = "\(name!)"
        }

        var nutrition = Set<HKSample>()
        for (key, identifier) in HealthConstants.NUTRITION_KEYS {
            let value = arguments[key] as? Double
            guard let unwrappedValue = value else { continue }
            let unit =
                key == "calories"
                    ? HKUnit.kilocalorie()
                    : key == "water" ? HKUnit.literUnit(with: .milli) : HKUnit.gram()
            let nutritionSample = HKQuantitySample(
                type: HKSampleType.quantityType(forIdentifier: identifier)!,
                quantity: HKQuantity(unit: unit, doubleValue: unwrappedValue), start: dateFrom,
                end: dateTo, metadata: metadata
            )
            nutrition.insert(nutritionSample)
        }

        if #available(iOS 15.0, *) {
            let type = HKCorrelationType.correlationType(
                forIdentifier: HKCorrelationTypeIdentifier.food
            )!
            let meal = HKCorrelation(
                type: type, start: dateFrom, end: dateTo, objects: nutrition, metadata: metadata
            )

            healthStore.save(
                meal,
                withCompletion: { success, error in
                    if let err = error {
                        print("Error Saving Meal Sample: \(err.localizedDescription)")
                    }
                    DispatchQueue.main.async {
                        result(success)
                    }
                }
            )
        } else {
            result(false)
        }
    }
}
