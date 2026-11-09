import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes menstruation flow data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeMenstruationFlow(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let flow = (arguments["value"] as? Int),
              let endTime = (arguments["endTime"] as? NSNumber),
              let isStartOfCycle = (arguments["isStartOfCycle"] as? NSNumber),
              let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(
                message: "Invalid Arguments - value, startTime, endTime or isStartOfCycle invalid"
            )
        }
        guard let menstrualFlowType = HKCategoryValueMenstrualFlow(rawValue: flow) else {
            throw PluginError(message: "Invalid Menstrual Flow Type")
        }

        let dateTime = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue

        guard let categoryType = HKSampleType.categoryType(forIdentifier: .menstrualFlow) else {
            throw PluginError(message: "Invalid Menstrual Flow Type")
        }

        let metadata =
            [
                HKMetadataKeyMenstrualCycleStart: isStartOfCycle,
                HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
            ] as [String: Any]

        let sample = HKCategorySample(
            type: categoryType,
            value: menstrualFlowType.rawValue,
            start: dateTime,
            end: dateTime,
            metadata: metadata
        )

        healthStore.save(
            sample,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Menstruation Flow Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }
}
