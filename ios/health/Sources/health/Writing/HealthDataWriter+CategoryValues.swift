import Flutter
import HealthKit

extension HealthDataWriter {
    /// The value a sample of a sleep or headache type gets: the value the type covers
    /// (CategoryValues). Sleep "stages" (light/deep/rem) are iOS 16+ and fall back to asleep on
    /// older versions. nil for any other type, whose value the caller gives.
    /// - Parameter sleepStages: Whether HealthKit has the sleep stages (CategoryValues.hasSleepStages)
    func resolvedCategoryValue(for type: String, sleepStages: Bool = CategoryValues.hasSleepStages) -> Int? {
        guard case let .only(value)? = CategoryValues(type) else { return nil }
        if !sleepStages, CategoryValues.sleepStageTypes.contains(type) {
            return HKCategoryValueSleepAnalysis.asleep.rawValue
        }
        return value
    }

    /// The values HealthKit takes for a sample of [type], one of the category types writeData and
    /// writeDataUUID write; it raises an exception (crashing the app) for any other value. nil for
    /// a category type they do not write.
    func acceptedValues(
        of type: HKCategoryType, sleepStages: Bool = CategoryValues.hasSleepStages
    ) -> ClosedRange<Int>? {
        switch HKCategoryTypeIdentifier(rawValue: type.identifier) {
        case .sleepAnalysis:
            // inBed, asleep and awake; asleepCore, asleepDeep and asleepREM from iOS 16 on.
            0...(sleepStages ? 5 : 2)
        case .appleStandHour:
            HKCategoryValueAppleStandHour.stood.rawValue...HKCategoryValueAppleStandHour.idle.rawValue
        case .headache:
            HKCategoryValueSeverity.unspecified.rawValue...HKCategoryValueSeverity.severe.rawValue
        case .highHeartRateEvent, .lowHeartRateEvent, .irregularHeartRhythmEvent, .mindfulSession:
            HKCategoryValue.notApplicable.rawValue...HKCategoryValue.notApplicable.rawValue
        default:
            nil
        }
    }

    /// The value of the category sample of [type] that writeData and writeDataUUID create: the
    /// type's own value (resolvedCategoryValue) or else [value], one that HealthKit takes.
    /// - Throws: PluginError for a type without a value of its own (SLEEP_UNKNOWN) or a value
    ///   HealthKit does not take for [categoryType]
    func checkCategoryValue(
        _ value: Double, of type: String, for categoryType: HKCategoryType,
        sleepStages: Bool = CategoryValues.hasSleepStages
    ) throws -> Int {
        if case .allBut? = CategoryValues(type) {
            throw PluginError(message: "\(type) cannot be written: HealthKit has no value for it")
        }
        // Int(value) itself crashes for a value no Int can hold, such as NaN.
        let categoryValue = resolvedCategoryValue(for: type, sleepStages: sleepStages)
            ?? Int(exactly: value.rounded(.towardZero))
        guard let categoryValue,
              acceptedValues(of: categoryType, sleepStages: sleepStages)?.contains(categoryValue) == true
        else {
            throw PluginError(message: "Value \(value) cannot be written for \(type)")
        }
        return categoryValue
    }

    /// The checked value of the category sample of [type] that writeData and writeDataUUID
    /// create (checkCategoryValue), replying an INVALID_ARGUMENT error for a value HealthKit does
    /// not take.
    /// - Returns: nil after replying the error: the write must then stop without replying again
    func validCategoryValue(
        _ value: Double, of type: String, for categoryType: HKCategoryType, result: FlutterResult
    ) -> Int? {
        do {
            return try checkCategoryValue(value, of: type, for: categoryType)
        } catch {
            let message = (error as? PluginError)?.message ?? error.localizedDescription
            result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
            return nil
        }
    }

    /// Replies an INVALID_ARGUMENT error for a type that writeData and writeDataUUID do not write:
    /// HealthKit raises an exception (crashing the app) for a menstrual flow or insulin delivery
    /// sample without the metadata that only their own writers set.
    /// - Returns: false after replying the error: the write must then stop without replying again
    func validateWritable(_ type: String, result: FlutterResult) -> Bool {
        let writer: String
        switch type {
        case HealthConstants.MENSTRUATION_FLOW:
            writer = "writeMenstruationFlow"
        case HealthConstants.INSULIN_DELIVERY:
            writer = "writeInsulinDelivery"
        default:
            return true
        }
        let message = "Use \(writer) to write \(type) on iOS: HealthKit requires metadata that only it sets"
        result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
        return false
    }
}
