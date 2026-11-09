import HealthKit

extension HealthDataReader {
    /// Builds the maps of [ecgSamples] in their order, reading each one's voltage measurements.
    /// Fails if a voltage query fails.
    @available(iOS 14.0, *)
    func ecgDictionaries(
        _ ecgSamples: [HKElectrocardiogram], completion: @escaping (Result<[Any], Error>) -> Void
    ) {
        guard !ecgSamples.isEmpty else {
            completion(.success([]))
            return
        }

        let group = DispatchGroup()
        var dictionaries = [NSDictionary?](repeating: nil, count: ecgSamples.count)
        var capturedError: Error?
        let lock = NSLock()

        for (index, ecg) in ecgSamples.enumerated() {
            group.enter()

            var voltageValues = [[String: Any]]()
            let expected = Int(ecg.numberOfVoltageMeasurements)
            if expected > 0 {
                voltageValues.reserveCapacity(expected)
            }

            let q = HKElectrocardiogramQuery(ecg) { _, res in
                switch res {
                case let .measurement(m):
                    if let v = m.quantity(for: .appleWatchSimilarToLeadI)?
                        .doubleValue(for: HKUnit.volt())
                    {
                        voltageValues.append([
                            "voltage": v,
                            "timeSinceSampleStart": m.timeSinceSampleStart,
                        ])
                    }
                case .done:
                    let dict = self.ecgDictionary(ecg, voltageValues: voltageValues)
                    lock.lock()
                    dictionaries[index] = dict
                    lock.unlock()
                    group.leave()
                case let .error(e):
                    lock.lock()
                    if HealthUtilities.isNoData(e) {
                        // An ECG without voltage measurements.
                        dictionaries[index] = self.ecgDictionary(ecg, voltageValues: voltageValues)
                    } else if capturedError == nil {
                        capturedError = e
                    }
                    lock.unlock()
                    group.leave()
                @unknown default:
                    // .done and .error end the query; ignore anything else.
                    break
                }
            }
            healthStore.execute(q)
        }

        // Reply from a background queue: encoding the voltages on main would stall the UI.
        group.notify(queue: .global(qos: .userInitiated)) {
            if let error = capturedError {
                completion(.failure(error))
            } else {
                completion(.success(dictionaries.compactMap { $0 }))
            }
        }
    }

    @available(iOS 14.0, *)
    private func ecgDictionary(_ ecg: HKElectrocardiogram, voltageValues: [[String: Any]]) -> NSDictionary {
        [
            "uuid": "\(ecg.uuid)",
            "voltageValues": voltageValues,
            "averageHeartRate": ecg.averageHeartRate?
                .doubleValue(
                    for: HKUnit.count()
                        .unitDivided(by: HKUnit.minute())
                ) as Any,
            "samplingFrequency": ecg.samplingFrequency?
                .doubleValue(for: HKUnit.hertz()) as Any,
            "classification": ecg.classification.rawValue,
            "date_from": Int(ecg.startDate.timeIntervalSince1970 * 1000),
            "date_to": Int(ecg.endDate.timeIntervalSince1970 * 1000),
            "source_id": ecg.sourceRevision.source.bundleIdentifier,
            "source_name": ecg.sourceRevision.source.name,
        ]
    }
}
