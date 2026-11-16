import HealthKit

/// Statistics separated by source: the quantities of each of their [sources], as HKStatistics of
/// a query with separateBySource has them. Tests stand in for HealthKit's with sources of their own.
protocol SourceSeparatedStatistics {
    associatedtype Source
    var sources: [Source]? { get }
    func sumQuantity(for source: Source) -> HKQuantity?
    func averageQuantity(for source: Source) -> HKQuantity?
    func minimumQuantity(for source: Source) -> HKQuantity?
    func maximumQuantity(for source: Source) -> HKQuantity?
}

extension HKStatistics: SourceSeparatedStatistics {}

extension HealthDataReader {
    /// Helper to select correct HKStatisticsOptions for a given dataTypeKey: the sum of a
    /// cumulative type such as STEPS, the average of a discrete one such as HEART_RATE.
    func statisticsOption(for dataTypeKey: String) -> HKStatisticsOptions {
        guard let quantityType = dataQuantityTypesDict[dataTypeKey] else {
            // Default to cumulativeSum for backward compatibility
            return .cumulativeSum
        }
        // HealthKit raises an exception (crashing the app) for an option the style does not support,
        // e.g. cumulativeSum for HEART_RATE, which is discreteTemporallyWeighted.
        switch quantityType.aggregationStyle {
        case .cumulative:
            return .cumulativeSum
        case .discreteArithmetic, .discreteTemporallyWeighted, .discreteEquivalentContinuousLevel:
            // Other options are .discreteAverage, .discreteMin, or .discreteMax
            return .discreteAverage
        @unknown default:
            // Every style added after .cumulative is a discrete one.
            return .discreteAverage
        }
    }

    /// The options of the statistics query that reads the intervals of [dataTypeKey]: its value
    /// (statisticsOption) and separateBySource, without which HKStatistics has no sources. Every
    /// aggregation style supports separateBySource.
    func intervalQueryOptions(for dataTypeKey: String) -> HKStatisticsOptions {
        statisticsOption(for: dataTypeKey).union(.separateBySource)
    }

    /// The option of [options] that selects an interval's value: separateBySource only adds the
    /// sources, and a switch compares whole option sets.
    static func valueOption(of options: HKStatisticsOptions) -> HKStatisticsOptions {
        options.subtracting(.separateBySource)
    }

    /// The value in [unit] of an interval's [statistics], read with the query [options]: the
    /// sum or the average of all its samples, not of one source.
    static func intervalValue(
        of statistics: HKStatistics, options: HKStatisticsOptions, unit: HKUnit
    ) -> Double? {
        let quantity: HKQuantity?
        switch valueOption(of: options) {
        case .cumulativeSum:
            quantity = statistics.sumQuantity()
        case .discreteAverage:
            quantity = statistics.averageQuantity()
        case .discreteMin:
            quantity = statistics.minimumQuantity()
        case .discreteMax:
            quantity = statistics.maximumQuantity()
        default:
            quantity = statistics.sumQuantity()
        }
        return quantity?.doubleValue(for: unit)
    }

    /// The sources of an interval's [statistics], read with the query [options], that have samples
    /// in it, in their order. A collection query lists every source of the collection in each of
    /// its intervals, also those without samples in it, whose quantity is nil.
    static func sourcesWithSamples<Statistics: SourceSeparatedStatistics>(
        of statistics: Statistics, options: HKStatisticsOptions
    ) -> [Statistics.Source] {
        (statistics.sources ?? []).filter { sourceQuantity(of: statistics, for: $0, options: options) != nil }
    }

    /// The quantity of one [source] in an interval's [statistics], read with the query [options]:
    /// its sum or its average, as intervalValue reads that of all sources.
    static func sourceQuantity<Statistics: SourceSeparatedStatistics>(
        of statistics: Statistics, for source: Statistics.Source, options: HKStatisticsOptions
    ) -> HKQuantity? {
        switch valueOption(of: options) {
        case .cumulativeSum:
            return statistics.sumQuantity(for: source)
        case .discreteAverage:
            return statistics.averageQuantity(for: source)
        case .discreteMin:
            return statistics.minimumQuantity(for: source)
        case .discreteMax:
            return statistics.maximumQuantity(for: source)
        default:
            return statistics.sumQuantity(for: source)
        }
    }

    /// The source keys of an interval, as Android sends them for its aggregates: the bundle
    /// identifiers of the apps and devices whose samples it holds, sorted and joined by ", ", as
    /// source_name, and an empty source_id, as no single source made the interval.
    static func intervalSource(bundleIdentifiers: [String]) -> [String: String] {
        ["source_id": "", "source_name": Set(bundleIdentifiers).sorted().joined(separator: ", ")]
    }
}
