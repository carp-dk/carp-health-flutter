import Flutter
import HealthKit

/// A stage of a sleep session, as SleepSessionStage on the Dart side: a sleep type's time range.
struct SleepSessionStage {
    let type: String
    let start: Date
    let end: Date
}

extension HealthDataWriter {
    /// Writes a sleep session with its stages. HealthKit has no session object, nor a title or
    /// notes: the session is saved as sleep analysis samples (sleepSessionSamples), all at once.
    /// - Parameters:
    ///   - call: Flutter method call with startTime and endTime (milliseconds since the epoch),
    ///     title and notes (a String or null, not stored), recordingMethod and stages, a list of
    ///     maps of type, startTime and endTime
    ///   - result: Flutter result callback: whether HealthKit saved the samples
    /// - Throws: PluginError when startTime, endTime, recordingMethod or stages is missing
    func writeSleepSession(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber),
              let recordingMethod = (arguments["recordingMethod"] as? Int),
              let stageArguments = (arguments["stages"] as? [Any])
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let samples: [HKCategorySample]
        do {
            let stages = try sleepSessionStages(from: stageArguments)
            // Each sample is a stage or lies inside the session, so checking these ranges checks them all.
            let sleepType = HKCategoryType(.sleepAnalysis)
            for (start, end) in [(dateFrom, dateTo)] + stages.map({ ($0.start, $0.end) }) {
                try checkSampleDates(start: start, end: end, of: sleepType)
            }
            samples = try sleepSessionSamples(
                start: dateFrom, end: dateTo, stages: stages, recordingMethod: recordingMethod
            )
        } catch {
            let message = (error as? PluginError)?.message ?? error.localizedDescription
            result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
            return
        }
        // A session spent out of bed has no sample.
        guard !samples.isEmpty else {
            result(true)
            return
        }

        healthStore.save(
            samples,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Sleep Session: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }

    /// The stages of a writeSleepSession call: maps of type, startTime and endTime (milliseconds
    /// since the epoch), as the Dart side sends them.
    /// - Throws: PluginError for a stage that is not such a map
    func sleepSessionStages(from arguments: [Any]) throws -> [SleepSessionStage] {
        try arguments.map { argument in
            guard let stage = argument as? NSDictionary,
                  let type = stage["type"] as? String,
                  let startTime = stage["startTime"] as? NSNumber,
                  let endTime = stage["endTime"] as? NSNumber
            else {
                throw PluginError(message: "A stage must be a map of type, startTime and endTime")
            }
            return SleepSessionStage(
                type: type,
                start: HealthUtilities.dateFromMilliseconds(startTime.doubleValue),
                end: HealthUtilities.dateFromMilliseconds(endTime.doubleValue)
            )
        }
    }

    /// The sleep analysis samples of a sleep session, which HealthKit has no object for: in-bed
    /// samples for the session without its SLEEP_OUT_OF_BED stages, then one sample per stage,
    /// in the order of the stages (sleepAnalysisValue). Dates must be checked first.
    /// - Parameters:
    ///   - recordingMethod: The recording method, manual entry (3) or else automatic
    ///   - sleepStages: Whether HealthKit has the sleep stages (CategoryValues.hasSleepStages)
    /// - Throws: PluginError for a stage type that is not a sleep stage, before any sample is created
    func sleepSessionSamples(
        start: Date, end: Date, stages: [SleepSessionStage], recordingMethod: Int,
        sleepStages: Bool = CategoryValues.hasSleepStages
    ) throws -> [HKCategorySample] {
        let values = try stages.map { try sleepAnalysisValue(ofStage: $0.type, sleepStages: sleepStages) }
        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
        ]
        let type = HKCategoryType(.sleepAnalysis)
        func sample(_ value: Int, _ range: (start: Date, end: Date)) -> HKCategorySample {
            HKCategorySample(type: type, value: value, start: range.start, end: range.end, metadata: metadata)
        }

        let outOfBed = stages.filter { $0.type == HealthConstants.SLEEP_OUT_OF_BED }
        let inBed = HealthDataWriter.uncoveredParts(
            of: (start, end), by: outOfBed.map { (start: $0.start, end: $0.end) }
        ).map { sample(HKCategoryValueSleepAnalysis.inBed.rawValue, $0) }
        return inBed + zip(stages, values).compactMap { stage, value in
            value.map { sample($0, (stage.start, stage.end)) }
        }
    }

    /// The sleep analysis value of the sample of a sleep session's stage: AWAKE and AWAKE_IN_BED
    /// are awake, ASLEEP asleep (unspecified), LIGHT, DEEP and REM core, deep and REM sleep (each
    /// resolvedCategoryValue). nil for a stage without a sample: out-of-bed time is left out of
    /// the in-bed samples and, as HealthKit has no unknown stage, an unknown stage stays in bed.
    /// - Throws: PluginError for a type that is not a sleep stage
    func sleepAnalysisValue(ofStage type: String, sleepStages: Bool) throws -> Int? {
        switch type {
        case HealthConstants.SLEEP_AWAKE, HealthConstants.SLEEP_AWAKE_IN_BED:
            return resolvedCategoryValue(for: HealthConstants.SLEEP_AWAKE, sleepStages: sleepStages)
        case HealthConstants.SLEEP_ASLEEP, HealthConstants.SLEEP_LIGHT, HealthConstants.SLEEP_DEEP,
             HealthConstants.SLEEP_REM:
            return resolvedCategoryValue(for: type, sleepStages: sleepStages)
        case HealthConstants.SLEEP_OUT_OF_BED, HealthConstants.SLEEP_UNKNOWN:
            return nil
        default:
            throw PluginError(message: "\(type) is not a sleep stage type")
        }
    }

    /// The parts of [range] that none of [ranges] covers, in order and none of them empty.
    static func uncoveredParts(
        of range: (start: Date, end: Date), by ranges: [(start: Date, end: Date)]
    ) -> [(start: Date, end: Date)] {
        var parts = [(start: Date, end: Date)]()
        var from = range.start
        for covered in ranges.sorted(by: { $0.start < $1.start }) {
            let to = min(covered.start, range.end)
            if from < to {
                parts.append((from, to))
            }
            from = max(from, covered.end)
        }
        if from < range.end {
            parts.append((from, range.end))
        }
        return parts
    }
}
