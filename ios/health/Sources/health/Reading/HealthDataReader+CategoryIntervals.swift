import Flutter
import HealthKit

/// One bucket of interval data: its time range in milliseconds since the epoch, how much of it
/// the data covers and the sources of that data.
struct IntervalBucket: Equatable {
    let start: Int
    let end: Int
    /// The milliseconds of the bucket that one or more data points cover.
    var covered: Int
    /// The sources of the data points that cover part of the bucket, each once, in the order the
    /// data points start.
    var sources: [String]

    var minutes: Double {
        Double(covered) / 60000
    }
}

/// A data type whose interval data is the time its category samples cover: the samples of
/// [type], only those with [values] if the type is shared by several data types.
struct CoverageCategory: Equatable {
    let type: HKCategoryType
    /// The category values of the data type, nil for all samples of [type].
    let values: CategoryValues?

    /// Whether [sample], a sample of [type], belongs to the data type.
    func contains(_ sample: HKCategorySample) -> Bool {
        values?.contains(sample.value) ?? true
    }
}

extension HealthDataReader {
    /// The category of [dataTypeKey] if its interval data is the time its samples cover: a sleep
    /// type, whose samples are those with its sleep analysis values, or MINDFULNESS, all mindful
    /// sessions. Nil for any other type, such as a headache type, which has no interval data.
    func coverageCategory(for dataTypeKey: String) -> CoverageCategory? {
        guard let type = dataTypesDict[dataTypeKey] as? HKCategoryType else { return nil }
        switch type.identifier {
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            return CategoryValues(dataTypeKey).map { CoverageCategory(type: type, values: $0) }
        case HKCategoryTypeIdentifier.mindfulSession.rawValue:
            return CoverageCategory(type: type, values: nil)
        default:
            return nil
        }
    }

    /// Gets the interval data of a sleep type or MINDFULNESS: for each bucket the time that the
    /// type's samples cover, overlapping samples counted once, in a unit of time (MINUTE by
    /// default). Buckets of [interval] seconds follow each other from [start]; the last one ends
    /// at [end]. As for other types, buckets without data are left out.
    /// - Parameters:
    ///   - start: Milliseconds since the epoch
    ///   - end: Milliseconds since the epoch
    ///   - category: The samples of the type, those getHealthDataFromTypes reads (coverageCategory)
    ///   - result: Flutter result callback, given the same keys as for other types
    func getCategoryIntervalData(
        dataTypeKey: String, unitKey: String?, start: Int, end: Int, interval: Int,
        includeManualEntry: Bool, category: CoverageCategory, result: @escaping FlutterResult
    ) {
        guard interval > 0 else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "interval must be at least 1 second", details: nil))
            return
        }
        var unit = HKUnit.minute()
        if let unitKey {
            // Converting to a unit of another kind raises an exception, which would crash the app.
            guard let requested = unitDict[unitKey],
                  HKQuantity(unit: unit, doubleValue: 0).is(compatibleWith: requested)
            else {
                let message = "Unit \(unitKey) cannot be used for \(dataTypeKey)"
                result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
                return
            }
            unit = requested
        }
        guard start < end else {
            result([])
            return
        }
        let (bucketLength, overflow) = interval.multipliedReportingOverflow(by: 1000)

        // Every sample of the type that overlaps the read, also one that starts before it.
        var predicates = [
            HKQuery.predicateForSamples(
                withStart: HealthUtilities.dateFromMilliseconds(Double(start)),
                end: HealthUtilities.dateFromMilliseconds(Double(end)), options: []
            ),
        ]
        if let values = category.values {
            predicates.append(values.predicate)
        }
        if !includeManualEntry {
            predicates.append(NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered))
        }

        let query = HKSampleQuery(
            sampleType: category.type,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samplesOrNil, error in
            if let error {
                if HealthUtilities.isNoData(error) {
                    result([])
                } else {
                    result(
                        HealthUtilities.flutterError(
                            for: error, operation: "getting \(dataTypeKey) intervals", fallbackCode: "STATISTICS_ERROR"
                        )
                    )
                }
                return
            }

            // The query already filters by value; this keeps the result right if HealthKit did not.
            let samples = (samplesOrNil ?? []).compactMap { $0 as? HKCategorySample }.filter(category.contains)
            result(
                HealthDataReader.coverageIntervals(
                    samples, start: start, end: end, bucket: overflow ? Int.max : bucketLength, unit: unit
                )
            )
        }
        healthStore.execute(query)
    }

    /// The interval maps of [samples]: for each bucket the time they cover in [unit] and, as
    /// Android sends them for its sleep intervals, the bundle identifiers of the samples that cover
    /// part of it, in the order the samples start and joined by ", ", as source_name, and an empty
    /// source_id, as no single source made the interval. Times as in minutesPerBucket.
    static func coverageIntervals(
        _ samples: [HKSample], start: Int, end: Int, bucket: Int, unit: HKUnit
    ) -> [[String: Any]] {
        let buckets = minutesPerBucket(
            samples.map {
                (
                    start: milliseconds($0.startDate), end: milliseconds($0.endDate),
                    source: $0.sourceRevision.source.bundleIdentifier
                )
            },
            start: start, end: end, bucket: bucket
        )
        return buckets.map { bucket -> [String: Any] in
            [
                "value": HKQuantity(unit: .minute(), doubleValue: bucket.minutes).doubleValue(for: unit),
                "date_from": bucket.start,
                "date_to": bucket.end,
                "source_id": "",
                "source_name": bucket.sources.joined(separator: ", "),
            ]
        }
    }

    /// The minutes of each bucket that [intervals] cover, overlapping intervals counted once, and
    /// the sources of the intervals that cover part of it (IntervalBucket.sources). Times are
    /// milliseconds since the epoch: buckets of [bucket] milliseconds follow each other from
    /// [start], the last one ending at [end]. Buckets that no interval covers are left out.
    static func minutesPerBucket(
        _ intervals: [(start: Int, end: Int, source: String)], start: Int, end: Int, bucket: Int
    ) -> [IntervalBucket] {
        guard bucket > 0 else { return [] }
        var buckets = [IntervalBucket]()
        // By start time, each interval adds the part of it that no earlier interval covers. The
        // parts follow each other, so a bucket is complete once a part lies beyond it.
        var coveredUntil = start
        // The last bucket (by number from start) that lists each source. A later interval of a
        // source starts no earlier, so it lists the source in the buckets after that one only.
        var listedUntil = [String: Int]()
        let order = intervals.indices.sorted { (intervals[$0].start, $0) < (intervals[$1].start, $1) }
        for index in order {
            let interval = intervals[index]
            var from = max(interval.start, coveredUntil)
            let to = min(interval.end, end)
            while from < to {
                let bucketStart = start + (from - start) / bucket * bucket
                let bucketEnd = end - bucketStart > bucket ? bucketStart + bucket : end
                let partEnd = min(to, bucketEnd)
                if buckets.last?.start == bucketStart {
                    buckets[buckets.count - 1].covered += partEnd - from
                } else {
                    buckets.append(
                        IntervalBucket(start: bucketStart, end: bucketEnd, covered: partEnd - from, sources: [])
                    )
                }
                from = partEnd
            }
            coveredUntil = max(coveredUntil, to)

            // Each bucket the interval covers part of lists its source. With the earlier ones, it
            // covers all time from its start to the last covered moment, in the last bucket: the
            // buckets from its start on are the last ones, numbered up to the last bucket's.
            let clippedStart = max(interval.start, start)
            guard clippedStart < to, let last = buckets.last else { continue }
            let lastNumber = (last.start - start) / bucket
            let toNumber = (to - 1 - start) / bucket
            let fromNumber = max((clippedStart - start) / bucket, (listedUntil[interval.source] ?? -1) + 1)
            guard fromNumber <= toNumber else { continue }
            for number in fromNumber ... toNumber {
                buckets[buckets.count - 1 - lastNumber + number].sources.append(interval.source)
            }
            listedUntil[interval.source] = toNumber
        }
        return buckets
    }
}

/// [date] in milliseconds since the epoch, rounded: a time the Dart side sent reads back unchanged.
private func milliseconds(_ date: Date) -> Int {
    Int((date.timeIntervalSince1970 * 1000).rounded())
}
