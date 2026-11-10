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
        guard validateSampleDates(start: dateFrom, end: dateTo, of: [sampleType], result: result) else { return }

        let sample: HKObject

        if let categoryType = sampleType as? HKCategoryType {
            let safeValue = resolvedCategoryValue(for: type, rawValue: Int(value))
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
        guard validateSampleDates(start: dateFrom, end: dateTo, of: [sampleType], result: result) else { return }

        let sample: HKObject

        if let categoryType = sampleType as? HKCategoryType {
            sample = HKCategorySample(
                type: categoryType, value: resolvedCategoryValue(for: type, rawValue: Int(value)),
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

    /// Returns a category value that is valid for the current iOS version.
    /// Sleep "stages" (light/deep/rem) are iOS 16+ and need fallback on older versions.
    private func resolvedCategoryValue(for type: String, rawValue: Int) -> Int {
        switch type {
        case HealthConstants.SLEEP_IN_BED:
            return HKCategoryValueSleepAnalysis.inBed.rawValue
        case HealthConstants.SLEEP_ASLEEP:
            return HKCategoryValueSleepAnalysis.asleep.rawValue
        case HealthConstants.SLEEP_AWAKE:
            return HKCategoryValueSleepAnalysis.awake.rawValue
        case HealthConstants.SLEEP_LIGHT:
            if #available(iOS 16.0, *) {
                return HKCategoryValueSleepAnalysis.asleepCore.rawValue
            }
            return HKCategoryValueSleepAnalysis.asleep.rawValue
        case HealthConstants.SLEEP_DEEP:
            if #available(iOS 16.0, *) {
                return HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            }
            return HKCategoryValueSleepAnalysis.asleep.rawValue
        case HealthConstants.SLEEP_REM:
            if #available(iOS 16.0, *) {
                return HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }
            return HKCategoryValueSleepAnalysis.asleep.rawValue
        default:
            return rawValue
        }
    }
}
