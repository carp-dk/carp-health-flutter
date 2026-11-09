import Flutter
import HealthKit

extension HealthDataReader {
    /// Error to reply with when [unit] cannot express [sampleType]. HKQuantity.doubleValue(for:)
    /// raises an Objective-C exception for an incompatible unit, which would crash the app.
    func incompatibleUnitError(
        _ sampleType: HKSampleType, unit: HKUnit?, dataTypeKey: String, unitKey: String?
    ) -> FlutterError? {
        guard let quantityType = sampleType as? HKQuantityType else { return nil }
        // Without a unit, values are read in international units (as before 14.0.0).
        if quantityType.is(compatibleWith: unit ?? HKUnit.internationalUnit()) { return nil }
        let message: String
        if let unitKey, unit == nil {
            message = "Unit \(unitKey) is not supported on iOS"
        } else {
            message = "Unit \(unitKey ?? "none") cannot be used for \(dataTypeKey)"
        }
        return FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil)
    }

    func samplePredicate(
        from dateFrom: Date, to dateTo: Date, includeManualEntry: Bool, dataTypeKey: String
    ) -> NSPredicate {
        var predicates = [HKQuery.predicateForSamples(withStart: dateFrom, end: dateTo, options: .strictStartDate)]
        if !includeManualEntry {
            predicates.append(NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered))
        }
        // Sleep stages and headache severities share one category type; filter by value in the query.
        if let value = HealthDataReader.categoryValues[dataTypeKey] {
            predicates.append(NSPredicate(format: "%K == %@", HKPredicateKeyPathCategoryValue, NSNumber(value: value)))
        }
        return predicates.count == 1 ? predicates[0] : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
