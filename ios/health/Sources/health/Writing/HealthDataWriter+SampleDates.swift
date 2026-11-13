import Flutter
import HealthKit

extension HealthDataWriter {
    /// Checks the time range of a sample before it is created. HealthKit raises an exception
    /// (crashing the app) for a sample that ends at or after Date.distantFuture, lasts longer
    /// than its type allows (4 days for most types) or shorter (1 ms for the audio exposure
    /// types, the only ones with a minimum).
    /// - Throws: PluginError for a time range the sample type does not accept
    func checkSampleDates(start: Date, end: Date, of type: HKSampleType) throws {
        guard start <= end else {
            throw PluginError(message: "startTime must be equal to or earlier than endTime")
        }
        guard end < Date.distantFuture else {
            throw PluginError(message: "endTime is too far in the future")
        }
        // maximumAllowedDuration itself raises for a type without a maximum, so check the flag first.
        if type.isMaximumDurationRestricted, end.timeIntervalSince(start) > type.maximumAllowedDuration {
            throw PluginError(
                message: "A \(type.identifier) sample can last at most "
                    + "\(Int(type.maximumAllowedDuration)) seconds"
            )
        }
        // The same for minimumAllowedDuration. HealthKit compares the duration as computed here, so
        // a range of exactly 1 ms, which comes out just below it for most dates, is refused too.
        if type.isMinimumDurationRestricted, end.timeIntervalSince(start) < type.minimumAllowedDuration {
            throw PluginError(
                message: "A \(type.identifier) sample must last at least "
                    + "\(type.minimumAllowedDuration) seconds"
            )
        }
    }

    /// Checks the time range of the samples a write is about to create, one or more of each of
    /// [types], and replies an INVALID_ARGUMENT error for a range one of the types does not accept.
    /// - Returns: false after replying the error: the write must then stop without replying again
    func validateSampleDates(start: Date, end: Date, of types: [HKSampleType], result: FlutterResult) -> Bool {
        do {
            for type in types {
                try checkSampleDates(start: start, end: end, of: type)
            }
            return true
        } catch {
            let message = (error as? PluginError)?.message ?? error.localizedDescription
            result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
            return false
        }
    }
}
