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

        // Sleep types and mindful sessions are categories, not quantities: their value is the time
        // their samples cover. (The headache types are categories too, without interval data.)
        if let category = coverageCategory(for: dataTypeKey) {
            getCategoryIntervalData(
                dataTypeKey: dataTypeKey, unitKey: dataUnitKey, start: startDate.intValue, end: endDate.intValue,
                interval: intervalInSecond, includeManualEntry: includeManualEntry, category: category, result: result
            )
            return
        }

        // interval in seconds
        var interval = DateComponents()
        interval.second = intervalInSecond

        let dateFrom = HealthUtilities.dateFromMilliseconds(startDate.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endDate.doubleValue)

        // The test getDataPage makes: a type this iOS version does not have is in neither dictionary.
        guard dataTypesDict[dataTypeKey] != nil || characteristicsTypesDict[dataTypeKey] != nil else {
            result(
                FlutterError(
                    code: "NOT_SUPPORTED",
                    message: "Data type \(dataTypeKey) is not available on this device",
                    details: nil
                )
            )
            return
        }
        // A type it has without interval data, such as a workout or a characteristic.
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

        let statisticsOptions = intervalQueryOptions(for: dataTypeKey)

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
                if let dataUnitKey, let unit = unitDict[dataUnitKey],
                   let value = HealthDataReader.intervalValue(of: statisticData, options: statisticsOptions, unit: unit)
                {
                    // The sources are set as the query separates them by source, all of them in
                    // each interval: those without samples in it are left out.
                    let sources = HealthDataReader.sourcesWithSamples(of: statisticData, options: statisticsOptions)
                    var dict: [String: Any] = HealthDataReader.intervalSource(
                        bundleIdentifiers: sources.map(\.bundleIdentifier)
                    )
                    dict["value"] = value
                    dict["date_from"] = Int(statisticData.startDate.timeIntervalSince1970 * 1000)
                    dict["date_to"] = Int(statisticData.endDate.timeIntervalSince1970 * 1000)
                    dictionaries.append(dict)
                }
            }
            result(dictionaries)
        }
        healthStore.execute(query)
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
