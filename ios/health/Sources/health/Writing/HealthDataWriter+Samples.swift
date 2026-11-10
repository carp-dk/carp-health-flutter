import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes general health data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeData(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let value = (arguments["value"] as? Double),
              let type = (arguments["dataTypeKey"] as? String),
              let unit = (arguments["dataUnitKey"] as? String),
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber),
              let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        // Handle mindfulness sessions specifically
        if type == HealthConstants.MINDFULNESS {
            try writeMindfulness(call: call, result: result)
            return
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
        ]

        guard let sampleType = dataTypesDict[type] else {
            print("Warning: Health data type '\(type)' not available on this iOS version.")
            result(false)
            return
        }
        guard validateWritable(type, result: result) else { return }
        guard validateSampleDates(start: dateFrom, end: dateTo, of: [sampleType], result: result) else { return }

        let sample: HKObject

        if let categoryType = sampleType as? HKCategoryType {
            // HealthKit raises an exception (crashing the app) for a value the type does not have.
            guard let safeValue = validCategoryValue(value, of: type, for: categoryType, result: result) else {
                return
            }
            sample = HKCategorySample(
                type: categoryType, value: safeValue, start: dateFrom,
                end: dateTo, metadata: metadata
            )
        } else if let quantityType = sampleType as? HKQuantityType {
            guard let hkUnit = unitDict[unit] else {
                print("Warning: Health data unit '\(unit)' not available on this iOS version.")
                result(false)
                return
            }
            // HealthKit raises an exception (crashing the app) for a unit that cannot express the type.
            guard quantityType.is(compatibleWith: hkUnit) else {
                result(incompatibleUnitError(unit: unit, type: type))
                return
            }
            guard validateQuantityValue(value, of: type, result: result) else { return }

            let quantity = HKQuantity(unit: hkUnit, doubleValue: value)
            sample = HKQuantitySample(
                type: quantityType, quantity: quantity, start: dateFrom,
                end: dateTo, metadata: metadata
            )
        } else {
            print("Warning: Unsupported HealthKit sample type for '\(type)'.")
            result(false)
            return
        }

        healthStore.save(
            sample,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving \(type) Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }

    /// Writes general health data and return UUID on success, otherwise an empty string
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeDataUUID(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let value = (arguments["value"] as? Double),
            let type = (arguments["dataTypeKey"] as? String),
            let unit = (arguments["dataUnitKey"] as? String),
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber),
            let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        // Handle mindfulness sessions specifically
        if type == HealthConstants.MINDFULNESS {
            try writeMindfulness(call: call, result: result)
            return
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry)
        ]

        guard let sampleType = dataTypesDict[type] else {
            print("Warning: Health data type '\(type)' not available on this iOS version.")
            result("")
            return
        }
        guard validateWritable(type, result: result) else { return }
        guard validateSampleDates(start: dateFrom, end: dateTo, of: [sampleType], result: result) else { return }

        let sample: HKObject

        if let categoryType = sampleType as? HKCategoryType {
            guard let safeValue = validCategoryValue(value, of: type, for: categoryType, result: result) else {
                return
            }
            sample = HKCategorySample(
                type: categoryType, value: safeValue,
                start: dateFrom, end: dateTo, metadata: metadata)
        } else if let quantityType = sampleType as? HKQuantityType {
            guard let hkUnit = unitDict[unit] else {
                print("Warning: Health data unit '\(unit)' not available on this iOS version.")
                result("")
                return
            }
            guard quantityType.is(compatibleWith: hkUnit) else {
                result(incompatibleUnitError(unit: unit, type: type))
                return
            }
            guard validateQuantityValue(value, of: type, result: result) else { return }
            let quantity = HKQuantity(unit: hkUnit, doubleValue: value)
            sample = HKQuantitySample(
                type: quantityType, quantity: quantity, start: dateFrom,
                end: dateTo, metadata: metadata)
        } else {
            print("Warning: Unsupported HealthKit sample type for '\(type)'.")
            result("")
            return
        }

        healthStore.save(
            sample,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving \(type) Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    // The UUID of the saved sample, an empty string if it was not saved
                    result(success ? sample.uuid.uuidString : "")
                }
            })
    }

    /// Writes mindfulness session data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeMindfulness(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber),
              let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
        ]

        guard let categoryType = HKSampleType.categoryType(forIdentifier: .mindfulSession) else {
            throw PluginError(message: "Invalid Mindfulness Session Type")
        }
        guard validateSampleDates(start: dateFrom, end: dateTo, of: [categoryType], result: result) else { return }

        // The duration is tracked by the start and end dates, not by the value
        let sample = HKCategorySample(
            type: categoryType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: dateFrom,
            end: dateTo,
            metadata: metadata
        )

        healthStore.save(
            sample,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Mindfulness Session: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }

    /// The error writeData and writeDataUUID reply with when [unit] cannot express [type], as reads do.
    private func incompatibleUnitError(unit: String, type: String) -> FlutterError {
        FlutterError(code: "INVALID_ARGUMENT", message: "Unit \(unit) cannot be used for \(type)", details: nil)
    }

    /// Replies an INVALID_ARGUMENT error for a value HealthKit does not take for [type]: it raises an
    /// exception (crashing the app) for a workout effort score outside 0 to 10. Their only unit is
    /// APPLE_EFFORT_SCORE, so [value] is the score. The keys are compared, which needs no iOS 18 check.
    /// - Returns: false after replying the error: the write must then stop without replying again
    private func validateQuantityValue(_ value: Double, of type: String, result: FlutterResult) -> Bool {
        let effortScores = [HealthConstants.WORKOUT_EFFORT_SCORE, HealthConstants.ESTIMATED_WORKOUT_EFFORT_SCORE]
        guard effortScores.contains(type), !(0.0...10.0).contains(value) else { return true }
        result(FlutterError(code: "INVALID_ARGUMENT", message: "\(type) must be between 0 and 10", details: nil))
        return false
    }
}
