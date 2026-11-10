import HealthKit

extension HealthDataWriter {
    /// Checks the time range of a sample before it is created. HealthKit raises an exception
    /// (crashing the app) for a sample that ends at or after Date.distantFuture or lasts longer
    /// than its type allows (4 days for most types).
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
    }
}
