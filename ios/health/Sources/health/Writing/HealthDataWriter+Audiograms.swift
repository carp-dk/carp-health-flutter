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

        let audiogram: HKAudiogramSample
        do {
            audiogram = try audiogramSample(
                frequencies: frequencies,
                leftEarSensitivities: leftEarSensitivities,
                rightEarSensitivities: rightEarSensitivities,
                start: HealthUtilities.dateFromMilliseconds(startTime.doubleValue),
                end: HealthUtilities.dateFromMilliseconds(endTime.doubleValue),
                metadata: try audiogramMetadata(from: arguments["metadata"])
            )
        } catch {
            let message = (error as? PluginError)?.message ?? error.localizedDescription
            result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
            return
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

    /// The audiogram to save. HKAudiogramSample raises an exception (crashing the app) for points
    /// or dates it does not accept, so they are checked here first.
    /// - Throws: PluginError, or HealthKit's error for a frequency or sensitivity out of range
    func audiogramSample(
        frequencies: [Double], leftEarSensitivities: [Double], rightEarSensitivities: [Double],
        start: Date, end: Date, metadata: [String: Any]?
    ) throws -> HKAudiogramSample {
        guard !frequencies.isEmpty,
              leftEarSensitivities.count == frequencies.count,
              rightEarSensitivities.count == frequencies.count
        else {
            throw PluginError(
                message: "frequencies, leftEarSensitivities and rightEarSensitivities must be "
                    + "non-empty and of the same length"
            )
        }
        // HealthKit's limit, see HKAudiogramSample.
        guard frequencies.count <= 30 else {
            throw PluginError(message: "An audiogram can have at most 30 frequencies")
        }
        guard zip(frequencies, frequencies.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw PluginError(message: "frequencies must be unique and in ascending order")
        }
        try checkSampleDates(start: start, end: end, of: HKObjectType.audiogramSampleType())

        let decibels = HKUnit.decibelHearingLevel()
        let sensitivityPoints = try frequencies.indices.map { index in
            try HKAudiogramSensitivityPoint(
                frequency: HKQuantity(unit: HKUnit.hertz(), doubleValue: frequencies[index]),
                leftEarSensitivity: HKQuantity(unit: decibels, doubleValue: leftEarSensitivities[index]),
                rightEarSensitivity: HKQuantity(unit: decibels, doubleValue: rightEarSensitivities[index])
            )
        }
        return HKAudiogramSample(
            sensitivityPoints: sensitivityPoints, start: start, end: end, metadata: metadata
        )
    }

    /// The metadata of an audiogram: the device name and the external UUID, each optional.
    /// - Throws: PluginError for a value that is not a String, which HealthKit does not accept
    func audiogramMetadata(from argument: Any?) throws -> [String: Any]? {
        guard let values = argument as? [String: Any] else { return nil }
        var metadata = [String: Any]()
        // The Dart side uses HealthKit's key names, "HKDeviceName" and "HKExternalUUID".
        for key in [HKMetadataKeyDeviceName, HKMetadataKeyExternalUUID] {
            guard let value = values[key], !(value is NSNull) else { continue }
            guard let text = value as? String else {
                throw PluginError(message: "metadata \(key) must be a String")
            }
            metadata[key] = text
        }
        return metadata.isEmpty ? nil : metadata
    }
}
