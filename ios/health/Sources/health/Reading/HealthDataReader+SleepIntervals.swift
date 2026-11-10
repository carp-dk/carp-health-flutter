import Flutter
import HealthKit

/// One bucket of interval data: its time range in milliseconds since the epoch, how much of it
/// the data covers and which data point covers the first moment of it that is covered.
struct IntervalBucket: Equatable {
    let start: Int
    let end: Int
    /// The milliseconds of the bucket that one or more data points cover.
    var covered: Int
    /// The index of the data point covering the bucket's first covered moment.
    let firstInterval: Int

    var minutes: Double {
        Double(covered) / 60000
    }
}

extension HealthDataReader {
    /// The test of the sleep analysis values a sleep data type covers: those of the samples
    /// getHealthDataFromTypes reads for it. nil for any other data type, such as the headache
    /// severities, which are category values of another type.
    func sleepValueTest(for dataTypeKey: String) -> ((Int) -> Bool)? {
        guard dataTypesDict[dataTypeKey]?.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
              let value = HealthDataReader.categoryValues[dataTypeKey]
        else { return nil }
        return { $0 == value }
    }

    /// Gets the interval data of a sleep type: for each bucket the time that the type's samples
    /// cover, overlapping samples counted once, in a unit of time (MINUTE by default). Buckets of
    /// [interval] seconds follow each other from [start]; the last one ends at [end]. As for other
    /// types, buckets without data are left out.
    /// - Parameters:
    ///   - start: Milliseconds since the epoch
    ///   - end: Milliseconds since the epoch
    ///   - valueTest: The test of the sample values that belong to the type (sleepValueTest)
    ///   - result: Flutter result callback, given the same keys as for other types
    func getSleepIntervalData(
        dataTypeKey: String, unitKey: String?, start: Int, end: Int, interval: Int,
        includeManualEntry: Bool, valueTest: @escaping (Int) -> Bool, result: @escaping FlutterResult
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

        // Every sample that overlaps the read, also one that starts before it.
        var predicate = HKQuery.predicateForSamples(
            withStart: HealthUtilities.dateFromMilliseconds(Double(start)),
            end: HealthUtilities.dateFromMilliseconds(Double(end)), options: []
        )
        if !includeManualEntry {
            let manualPredicate = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, manualPredicate])
        }

        let query = HKSampleQuery(
            sampleType: HKCategoryType(.sleepAnalysis), predicate: predicate, limit: HKObjectQueryNoLimit,
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

            let samples = (samplesOrNil ?? []).compactMap { $0 as? HKCategorySample }.filter { valueTest($0.value) }
            let buckets = HealthDataReader.minutesPerBucket(
                samples.map { (start: milliseconds($0.startDate), end: milliseconds($0.endDate)) },
                start: start, end: end, bucket: overflow ? Int.max : bucketLength
            )
            result(buckets.map { bucket -> [String: Any] in
                let source = samples[bucket.firstInterval].sourceRevision.source
                return [
                    "value": HKQuantity(unit: .minute(), doubleValue: bucket.minutes).doubleValue(for: unit),
                    "date_from": bucket.start,
                    "date_to": bucket.end,
                    "source_id": source.bundleIdentifier,
                    "source_name": source.name,
                ]
            })
        }
        healthStore.execute(query)
    }

    /// The minutes of each bucket that [intervals] cover, overlapping intervals counted once.
    /// Times are milliseconds since the epoch: buckets of [bucket] milliseconds follow each other
    /// from [start], the last one ending at [end]. Buckets that no interval covers are left out.
    static func minutesPerBucket(
        _ intervals: [(start: Int, end: Int)], start: Int, end: Int, bucket: Int
    ) -> [IntervalBucket] {
        guard bucket > 0 else { return [] }
        var buckets = [IntervalBucket]()
        // By start time, each interval adds the part of it that no earlier interval covers. The
        // parts follow each other, so a bucket is complete once a part lies beyond it.
        var coveredUntil = start
        let order = intervals.indices.sorted { (intervals[$0].start, $0) < (intervals[$1].start, $1) }
        for index in order {
            var from = max(intervals[index].start, coveredUntil)
            let to = min(intervals[index].end, end)
            while from < to {
                let bucketStart = start + (from - start) / bucket * bucket
                let bucketEnd = end - bucketStart > bucket ? bucketStart + bucket : end
                let partEnd = min(to, bucketEnd)
                if buckets.last?.start == bucketStart {
                    buckets[buckets.count - 1].covered += partEnd - from
                } else {
                    buckets.append(
                        IntervalBucket(start: bucketStart, end: bucketEnd, covered: partEnd - from, firstInterval: index)
                    )
                }
                from = partEnd
            }
            coveredUntil = max(coveredUntil, to)
        }
        return buckets
    }
}

/// [date] in milliseconds since the epoch, rounded: a time the Dart side sent reads back unchanged.
private func milliseconds(_ date: Date) -> Int {
    Int((date.timeIntervalSince1970 * 1000).rounded())
}
