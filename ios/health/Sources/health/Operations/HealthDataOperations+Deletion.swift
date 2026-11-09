import Flutter
import HealthKit

extension HealthDataOperations {
    /// Delete health data by date range
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func delete(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? NSDictionary,
              let dataTypeKey = arguments["dataTypeKey"] as? String
        else {
            print("Error: Missing dataTypeKey in arguments")
            result(false)
            return
        }

        // Check if it's a characteristic type - these cannot be deleted
        if characteristicsTypesDict[dataTypeKey] != nil {
            print(
                "Info: Cannot delete characteristic type '\(dataTypeKey)' - these are read-only system values"
            )
            result(false)
            return
        }

        let startTime = (arguments["startTime"] as? NSNumber) ?? 0
        let endTime = (arguments["endTime"] as? NSNumber) ?? 0

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        guard let dataType = dataTypesDict[dataTypeKey] else {
            print("Warning: Health data type '\(dataTypeKey)' not found in dataTypesDict")
            result(false)
            return
        }

        let samplePredicate = HKQuery.predicateForSamples(
            withStart: dateFrom, end: dateTo, options: .strictStartDate
        )
        let ownerPredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let deleteQuery = HKSampleQuery(
            sampleType: dataType,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                samplePredicate, ownerPredicate,
            ]),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samplesOrNil, error in
            guard let self else { return }

            guard let samplesOrNil, error == nil else {
                print(
                    "Error querying \(dataType) samples: \(error?.localizedDescription ?? "Unknown error")"
                )
                DispatchQueue.main.async {
                    result(false)
                }
                return
            }

            // Chcek if there are any samples to delete
            if samplesOrNil.isEmpty {
                print("Info: No \(dataType) samples found in the specified date range.")
                DispatchQueue.main.async {
                    result(true)
                }
                return
            }

            // Delete the retrieved objects from the HealthKit store
            healthStore.delete(samplesOrNil) { success, error in
                if let err = error {
                    print("Error deleting \(dataType) Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        }

        healthStore.execute(deleteQuery)
    }

    /// Delete health data by UUID
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func deleteByUUID(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let uuidarg = arguments["uuid"] as? String,
              let dataTypeKey = arguments["dataTypeKey"] as? String
        else {
            throw PluginError(message: "Invalid Arguments - UUID or DataTypeKey invalid")
        }

        guard let dataTypeToRemove = dataTypesDict[dataTypeKey] else {
            print("Warning: Health data type '\(dataTypeKey)' not found in dataTypesDict")
            result(false)
            return
        }

        guard let uuid = UUID(uuidString: uuidarg) else {
            result(false)
            return
        }
        let predicate = HKQuery.predicateForObjects(with: [uuid])

        let query = HKSampleQuery(
            sampleType: dataTypeToRemove,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { [weak self] _, samplesOrNil, error in
            guard let self else { return }

            guard let samples = samplesOrNil, !samples.isEmpty else {
                DispatchQueue.main.async {
                    result(false)
                }
                return
            }

            healthStore.delete(samples) { success, error in
                if let error {
                    print("Error deleting sample with UUID \(uuid): \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        }

        healthStore.execute(query)
    }
}
