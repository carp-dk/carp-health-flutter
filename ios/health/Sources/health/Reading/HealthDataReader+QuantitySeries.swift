import HealthKit

/// How a read returns a quantity sample that holds a series of readings (`count` > 1).
/// HealthKit stores such samples for workouts saved on iOS, and condenses the samples of older
/// Apple Watch workouts into them; the sample's `quantity` is only the series' average (discrete
/// types) or sum (cumulative types).
enum SeriesExpansion {
    /// One point for the sample, with the series' summary value.
    case summary
    /// One point for each reading, with the reading's own value and date interval: newest first or
    /// oldest first, as the page.
    case readings(newestFirst: Bool)
}

/// One reading of a quantity series. HealthKit may merge equal consecutive readings into one,
/// so the interval can be longer than a single measurement.
struct SeriesReading {
    let quantity: HKQuantity
    let interval: DateInterval
}

extension HealthDataReader {
    /// Number of points [sample] gives when its series is read: the readings of a quantity
    /// sample, 1 for any other sample.
    static func pointCount(of sample: HKSample) -> Int {
        max((sample as? HKQuantitySample)?.count ?? 1, 1)
    }

    /// Number of leading samples that make a page of at most [limit] points, given the number of
    /// points each sample gives. A page holds at least one sample, however many points it gives.
    static func pageLength(pointCounts: [Int], limit: Int) -> Int {
        var points = 0
        for (index, count) in pointCounts.enumerated() {
            points += count
            if points > limit {
                return max(index, 1)
            }
        }
        return pointCounts.count
    }

    /// Reads the readings of the samples among [samples] that hold a series, in one query, oldest
    /// first by sample UUID. A sample of the result without readings has none in the store any
    /// more, e.g. because it was deleted after the sample query.
    func seriesReadings(
        of samples: [HKQuantitySample],
        completion: @escaping (Result<[UUID: [SeriesReading]], Error>) -> Void
    ) {
        let series = samples.filter { $0.count > 1 }
        // The samples of one page all have the page's quantity type.
        guard let quantityType = series.first?.quantityType else {
            completion(.success([:]))
            return
        }

        // HealthKit calls the handler serially, once for each reading and with done for the last.
        var readings = [UUID: [SeriesReading]]()
        var finished = false
        let query = HKQuantitySeriesSampleQuery(
            quantityType: quantityType, predicate: HKQuery.predicateForObjects(with: Set(series.map(\.uuid)))
        ) { _, quantity, interval, sample, done, error in
            guard !finished else { return }
            if let error {
                finished = true
                completion(HealthUtilities.isNoData(error) ? .success(readings) : .failure(error))
                return
            }
            if let quantity, let interval, let sample {
                readings[sample.uuid, default: []].append(SeriesReading(quantity: quantity, interval: interval))
            }
            if done {
                finished = true
                completion(.success(readings))
            }
        }
        // Without the sample, the handler would not say which series a reading belongs to.
        query.includeSample = true
        query.orderByQuantitySampleStartDate = true
        healthStore.execute(query)
    }
}
