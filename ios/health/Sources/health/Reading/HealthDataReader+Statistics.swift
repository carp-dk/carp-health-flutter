import Flutter
import HealthKit

extension HealthDataReader {
    /// Gets interval health data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func getIntervalData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let dataTypeKey = (arguments?["dataTypeKey"] as? String) ?? "DEFAULT"
        let dataUnitKey = (arguments?["dataUnitKey"] as? String)
        let startDate = (arguments?["startTime"] as? NSNumber) ?? 0
        let endDate = (arguments?["endTime"] as? NSNumber) ?? 0
        let intervalInSecond = (arguments?["interval"] as? Int) ?? 1
        let recordingMethodsToFilter = (arguments?["recordingMethodsToFilter"] as? [Int]) ?? []
        let includeManualEntry = !recordingMethodsToFilter.contains(
            HealthConstants.RecordingMethod.manual.rawValue
        )

        // interval in seconds
        var interval = DateComponents()
        interval.second = intervalInSecond

        let dateFrom = HealthUtilities.dateFromMilliseconds(startDate.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endDate.doubleValue)

        guard let quantityType = dataQuantityTypesDict[dataTypeKey] else {
            result(
                FlutterError(
                    code: "INVALID_TYPE",
                    message: "Invalid dataTypeKey for interval query: \(dataTypeKey)",
                    details: nil
                )
            )
            return
        }

        // Values are only read with a known unit; an incompatible one would crash the app.
        if let unit = dataUnitKey.flatMap({ unitDict[$0] }),
           let unitError = incompatibleUnitError(
               quantityType, unit: unit, dataTypeKey: dataTypeKey, unitKey: dataUnitKey
           )
        {
            result(unitError)
            return
        }

        var predicate = HKQuery.predicateForSamples(withStart: dateFrom, end: dateTo, options: [])
        if !includeManualEntry {
            let manualPredicate = NSPredicate(
                format: "metadata.%K != YES", HKMetadataKeyWasUserEntered
            )
            predicate = NSCompoundPredicate(
                type: .and, subpredicates: [predicate, manualPredicate]
            )
        }

        let statisticsOptions = statisticsOption(for: dataTypeKey)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: statisticsOptions,
            anchorDate: dateFrom,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, statisticCollectionOrNil, error in
            guard let self else {
                result(
                    FlutterError(
                        code: "INTERNAL_ERROR",
                        message: "Internal instance reference lost",
                        details: nil
                    )
                )
                return
            }

            if let error {
                if HealthUtilities.isNoData(error) {
                    result([])
                } else {
                    result(
                        HealthUtilities.flutterError(
                            for: error, operation: "getting statistics", fallbackCode: "STATISTICS_ERROR"
                        )
                    )
                }
                return
            }

            guard let collection = statisticCollectionOrNil else {
                result(nil)
                return
            }

            var dictionaries = [[String: Any]]()
            collection.enumerateStatistics(from: dateFrom, to: dateTo) {
                [weak self] statisticData, _ in
                guard let self else { return }
                if let dataUnitKey, let unit = unitDict[dataUnitKey] {
                    var value: Double? = nil
                    switch statisticsOptions {
                    case .cumulativeSum:
                        value = statisticData.sumQuantity()?.doubleValue(for: unit)
                    case .discreteAverage:
                        value = statisticData.averageQuantity()?.doubleValue(for: unit)
                    case .discreteMin:
                        value = statisticData.minimumQuantity()?.doubleValue(for: unit)
                    case .discreteMax:
                        value = statisticData.maximumQuantity()?.doubleValue(for: unit)
                    default:
                        value = statisticData.sumQuantity()?.doubleValue(for: unit)
                    }
                    if let value {
                        let dict = [
                            "value": value,
                            "date_from": Int(statisticData.startDate.timeIntervalSince1970 * 1000),
                            "date_to": Int(statisticData.endDate.timeIntervalSince1970 * 1000),
                            "source_id": statisticData.sources?.first?.bundleIdentifier ?? "",
                            "source_name": statisticData.sources?.first?.name ?? "",
                        ]
                        dictionaries.append(dict)
                    }
                }
            }
            result(dictionaries)
        }
        healthStore.execute(query)
    }

    /// Helper to select correct HKStatisticsOptions for a given dataTypeKey
    private func statisticsOption(for dataTypeKey: String) -> HKStatisticsOptions {
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

    /// Gets total steps in interval
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func getTotalStepsInInterval(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let startTime = (arguments?["startTime"] as? NSNumber) ?? 0
        let endTime = (arguments?["endTime"] as? NSNumber) ?? 0
        let recordingMethodsToFilter = (arguments?["recordingMethodsToFilter"] as? [Int]) ?? []
        let includeManualEntry = !recordingMethodsToFilter.contains(
            HealthConstants.RecordingMethod.manual.rawValue
        )

        // Convert dates from milliseconds to Date()
        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let sampleType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        var predicate = HKQuery.predicateForSamples(
            withStart: dateFrom, end: dateTo, options: .strictStartDate
        )
        if !includeManualEntry {
            let manualPredicate = NSPredicate(
                format: "metadata.%K != YES", HKMetadataKeyWasUserEntered
            )
            predicate = NSCompoundPredicate(
                type: .and, subpredicates: [predicate, manualPredicate]
            )
        }

        let query = HKStatisticsCollectionQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: dateFrom,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, results, error in
            guard let results else {
                if let error, HealthUtilities.isNoData(error) {
                    result(0)
                } else if let error {
                    result(
                        HealthUtilities.flutterError(
                            for: error, operation: "getting step count", fallbackCode: "STEPS_ERROR"
                        )
                    )
                } else {
                    result(
                        FlutterError(
                            code: "STEPS_ERROR",
                            message: "Error getting step count: Unknown error",
                            details: nil
                        )
                    )
                }
                return
            }

            var totalSteps = 0.0
            results.enumerateStatistics(from: dateFrom, to: dateTo) { statistics, _ in
                if let quantity = statistics.sumQuantity() {
                    let unit = HKUnit.count()
                    totalSteps += quantity.doubleValue(for: unit)
                }
            }

            result(Int(totalSteps))
        }

        healthStore.execute(query)
    }
}
