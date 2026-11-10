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

        let systolicType = HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!
        let diastolicType = HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
        let bpCorrelationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!
        guard validateSampleDates(
            start: dateFrom, end: dateTo, of: [systolicType, diastolicType, bpCorrelationType], result: result
        ) else { return }

        let systolic_sample = HKQuantitySample(
            type: systolicType,
            quantity: HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: systolic),
            start: dateFrom, end: dateTo, metadata: metadata
        )
        let diastolic_sample = HKQuantitySample(
            type: diastolicType,
            quantity: HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: diastolic),
            start: dateFrom, end: dateTo, metadata: metadata
        )
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
              let startTime = (arguments["start_time"] as? NSNumber),
              let endTime = (arguments["end_time"] as? NSNumber),
              let recordingMethod = arguments["recordingMethod"] as? Int
        else {
            throw PluginError(message: "Invalid Arguments")
        }
        // Optional: Dart sends null (NSNull) when they are not set.
        let name = arguments["name"] as? String
        let mealType = arguments["meal_type"] as? String

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue

        var metadata =
            [
                "HKFoodMeal": mealType ?? "UNKNOWN",
                HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
            ] as [String: Any]
        if let name {
            metadata[HKMetadataKeyFoodType] = name
        }

        // The meal and a sample of each nutrient the call sets, all over the meal's time range.
        let foodType = HKCorrelationType.correlationType(forIdentifier: .food)!
        let nutrientTypes: [HKSampleType] = HealthConstants.NUTRITION_KEYS.compactMap { key, identifier in
            arguments[key] is Double ? HKSampleType.quantityType(forIdentifier: identifier) : nil
        }
        // HealthKit raises an exception (crashing the app) for a meal without samples.
        guard !nutrientTypes.isEmpty else {
            let message = "A meal needs at least one nutrient value (HealthKit has no type for fatTransMonoenoic)"
            result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
            return
        }
        guard validateSampleDates(
            start: dateFrom, end: dateTo, of: nutrientTypes + [foodType], result: result
        ) else { return }

        var nutrition = Set<HKSample>()
        for (key, identifier) in HealthConstants.NUTRITION_KEYS {
            guard let unwrappedValue = arguments[key] as? Double else { continue }
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
            let meal = HKCorrelation(
                type: foodType, start: dateFrom, end: dateTo, objects: nutrition, metadata: metadata
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
