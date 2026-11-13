import HealthKit

/// The category values a data type covers where several data types share one HealthKit category
/// type: the sleep types share sleepAnalysis and the headache types share headache. Reads, sleep
/// intervals, writes and deletes of such a data type only take the samples with its values.
enum CategoryValues: Equatable {
    /// The samples with this value.
    case only(Int)
    /// The samples with any value but these, which the other data types of the category type cover.
    case allBut([Int])

    /// The sleep analysis value (HKCategoryValueSleepAnalysis) each sleep type covers. HealthKit's
    /// asleepUnspecified is SLEEP_ASLEEP, as Health Connect's SLEEPING is.
    static let sleepValues: [String: Int] = [
        HealthConstants.SLEEP_IN_BED: 0, // inBed
        HealthConstants.SLEEP_ASLEEP: 1, // asleepUnspecified
        HealthConstants.SLEEP_AWAKE: 2, // awake
        HealthConstants.SLEEP_LIGHT: 3, // asleepCore
        HealthConstants.SLEEP_DEEP: 4, // asleepDeep
        HealthConstants.SLEEP_REM: 5, // asleepREM
    ]

    /// The severity (HKCategoryValueSeverity) each headache type covers.
    static let headacheValues: [String: Int] = [
        HealthConstants.HEADACHE_UNSPECIFIED: 0,
        HealthConstants.HEADACHE_NOT_PRESENT: 1,
        HealthConstants.HEADACHE_MILD: 2,
        HealthConstants.HEADACHE_MODERATE: 3,
        HealthConstants.HEADACHE_SEVERE: 4,
    ]

    /// The sleep types whose values HealthKit has from iOS 16 on only.
    static let sleepStageTypes: Set<String> = [
        HealthConstants.SLEEP_LIGHT, HealthConstants.SLEEP_DEEP, HealthConstants.SLEEP_REM,
    ]

    /// Whether HealthKit has the values of sleepStageTypes: iOS 16 and later.
    static var hasSleepStages: Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return false
    }

    /// The values [dataTypeKey] covers, nil for a data type that has its category type to itself
    /// (or is no category type), which covers all of its samples. SLEEP_UNKNOWN covers the sleep
    /// analysis values the plugin has no type for: none in today's SDK, values Apple adds later.
    init?(_ dataTypeKey: String) {
        if let value = CategoryValues.sleepValues[dataTypeKey] ?? CategoryValues.headacheValues[dataTypeKey] {
            self = .only(value)
        } else if dataTypeKey == HealthConstants.SLEEP_UNKNOWN {
            self = .allBut(CategoryValues.sleepValues.values.sorted())
        } else {
            return nil
        }
    }

    /// Whether a sample with [value] belongs to the data type: the test of samples in memory.
    func contains(_ value: Int) -> Bool {
        switch self {
        case let .only(covered):
            value == covered
        case let .allBut(others):
            !others.contains(value)
        }
    }

    /// The query predicate that keeps the data type's samples.
    var predicate: NSPredicate {
        switch self {
        case let .only(value):
            CategoryValues.valueEqualTo(value)
        case let .allBut(others):
            // HealthKit raises an exception (crashing the app) for "value IN {...}" in a query.
            NSCompoundPredicate(
                notPredicateWithSubpredicate: NSCompoundPredicate(
                    orPredicateWithSubpredicates: others.map(CategoryValues.valueEqualTo)
                )
            )
        }
    }

    private static func valueEqualTo(_ value: Int) -> NSPredicate {
        NSPredicate(format: "%K == %@", HKPredicateKeyPathCategoryValue, NSNumber(value: value))
    }
}
