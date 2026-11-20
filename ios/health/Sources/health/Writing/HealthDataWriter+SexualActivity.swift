import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes sexual activity data as an `HKCategoryTypeIdentifier.sexualActivity` sample.
    ///
    /// When `protectionUsed` is a boolean, sets `HKMetadataKeySexualActivityProtectionUsed`;
    /// when omitted or `NSNull`, omits the key so HealthKit stores it as unspecified.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeSexualActivity(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber),
              let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(
                message: "Invalid Arguments - startTime, endTime or recordingMethod invalid"
            )
        }

        let protectionUsed: Bool?
        if let rawProtection = arguments["protectionUsed"], !(rawProtection is NSNull) {
            guard CFGetTypeID(rawProtection as CFTypeRef) == CFBooleanGetTypeID(),
                  let boolValue = rawProtection as? Bool
            else {
                throw PluginError(message: "Invalid Arguments - protectionUsed must be a boolean or null")
            }
            protectionUsed = boolValue
        } else {
            protectionUsed = nil
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue

        guard let categoryType = HKSampleType.categoryType(forIdentifier: .sexualActivity) else {
            throw PluginError(message: "Invalid Sexual Activity Type")
        }
        guard validateSampleDates(start: dateFrom, end: dateTo, of: [categoryType], result: result) else { return }

        var metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
        ]
        if let protectionUsed {
            metadata[HKMetadataKeySexualActivityProtectionUsed] = NSNumber(value: protectionUsed)
        }

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
                    print("Error Saving Sexual Activity Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }
}
