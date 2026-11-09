import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes audiogram data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeAudiogram(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let frequencies = (arguments["frequencies"] as? [Double]),
              let leftEarSensitivities = (arguments["leftEarSensitivities"] as? [Double]),
              let rightEarSensitivities = (arguments["rightEarSensitivities"] as? [Double]),
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber)
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        var sensitivityPoints = [HKAudiogramSensitivityPoint]()

        for index in 0 ... frequencies.count - 1 {
            let frequency = HKQuantity(unit: HKUnit.hertz(), doubleValue: frequencies[index])
            let dbUnit = HKUnit.decibelHearingLevel()
            let left = HKQuantity(unit: dbUnit, doubleValue: leftEarSensitivities[index])
            let right = HKQuantity(unit: dbUnit, doubleValue: rightEarSensitivities[index])
            let sensitivityPoint = try HKAudiogramSensitivityPoint(
                frequency: frequency, leftEarSensitivity: left, rightEarSensitivity: right
            )
            sensitivityPoints.append(sensitivityPoint)
        }

        let audiogram: HKAudiogramSample
        let metadataReceived = (arguments["metadata"] as? [String: Any]?)

        if metadataReceived != nil {
            guard let deviceName = metadataReceived?!["HKDeviceName"] as? String else { return }
            guard let externalUUID = metadataReceived?!["HKExternalUUID"] as? String else { return }

            audiogram = HKAudiogramSample(
                sensitivityPoints: sensitivityPoints, start: dateFrom, end: dateTo,
                metadata: [
                    HKMetadataKeyDeviceName: deviceName, HKMetadataKeyExternalUUID: externalUUID,
                ]
            )

        } else {
            audiogram = HKAudiogramSample(
                sensitivityPoints: sensitivityPoints, start: dateFrom, end: dateTo, metadata: nil
            )
        }

        healthStore.save(
            audiogram,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Audiogram. Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }
}
