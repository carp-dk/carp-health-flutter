import Flutter
import HealthKit

/// Class responsible for reading health data from HealthKit
class HealthDataReader {
    /// Samples per getDataPage reply when the call does not say.
    static let defaultPageSize = 20000
    /// Most samples per getDataPage reply (Health.maxPageSize on the Dart side).
    static let maxPageSize = 50000
    /// Smaller pages for samples that carry a series: an ECG holds about 15000 voltage
    /// measurements and a workout route all of its locations.
    static let pageCaps: [String: Int] = [
        HealthConstants.ELECTROCARDIOGRAM: 10,
        HealthConstants.WORKOUT_ROUTE: 10,
    ]

    let healthStore: HKHealthStore
    let dataTypesDict: [String: HKSampleType]
    let dataQuantityTypesDict: [String: HKQuantityType]
    let unitDict: [String: HKUnit]
    /// The names reads give workouts, built once from the workoutActivityTypeMap passed to init.
    let workoutActivityNames: WorkoutActivityNames
    let characteristicsTypesDict: [String: HKCharacteristicType]

    /// - Parameters:
    ///   - healthStore: The HealthKit store
    ///   - dataTypesDict: Dictionary of data types
    ///   - dataQuantityTypesDict: Dictionary of quantity types
    ///   - unitDict: Dictionary of units
    ///   - workoutActivityTypeMap: Dictionary of workout activity types
    ///   - characteristicsTypesDict: Dictionary of characteristic types
    init(
        healthStore: HKHealthStore,
        dataTypesDict: [String: HKSampleType],
        dataQuantityTypesDict: [String: HKQuantityType],
        unitDict: [String: HKUnit],
        workoutActivityTypeMap: [String: HKWorkoutActivityType],
        characteristicsTypesDict: [String: HKCharacteristicType]
    ) {
        self.healthStore = healthStore
        self.dataTypesDict = dataTypesDict
        self.dataQuantityTypesDict = dataQuantityTypesDict
        self.unitDict = unitDict
        workoutActivityNames = WorkoutActivityNames(workoutActivityTypeMap)
        self.characteristicsTypesDict = characteristicsTypesDict
    }

    /// Gets health data
    /// Deprecated: Dart reads with getDataPage since 14.0.0 and calls this only for channel mocks written for older versions; remove in a later major version.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func getData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? NSDictionary,
              let dataTypeKey = arguments["dataTypeKey"] as? String
        else {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: "Missing required dataTypeKey argument",
                    details: nil
                )
            )
            return
        }

        let dataUnitKey = arguments["dataUnitKey"] as? String
        let startTime = (arguments["startTime"] as? NSNumber) ?? 0
        let endTime = (arguments["endTime"] as? NSNumber) ?? 0
        let limit = (arguments["limit"] as? Int) ?? HKObjectQueryNoLimit
        let recordingMethodsToFilter = (arguments["recordingMethodsToFilter"] as? [Int]) ?? []
        let includeManualEntry = !recordingMethodsToFilter.contains(
            HealthConstants.RecordingMethod.manual.rawValue
        )

        // convert from milliseconds to Date()
        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        // characteristic types checks (like GENDER, BLOOD_TYPE, etc.)
        if let point = characteristicDictionary(dataTypeKey, from: dateFrom, to: dateTo) {
            result([point])
            return
        }

        guard let dataType = dataTypesDict[dataTypeKey] else {
            result(
                FlutterError(
                    code: "INVALID_TYPE",
                    message: "Invalid dataTypeKey: \(dataTypeKey)",
                    details: nil
                )
            )
            return
        }

        let unit = dataUnitKey.flatMap { unitDict[$0] }
        if let unitError = incompatibleUnitError(dataType, unit: unit, dataTypeKey: dataTypeKey, unitKey: dataUnitKey) {
            result(unitError)
            return
        }

        let predicate = samplePredicate(
            from: dateFrom, to: dateTo, includeManualEntry: includeManualEntry, dataTypeKey: dataTypeKey
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: dataType, predicate: predicate, limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samplesOrNil, error in
            if let error {
                if HealthUtilities.isNoData(error) {
                    result([])
                } else {
                    result(HealthUtilities.flutterError(for: error, operation: "getting health data"))
                }
                return
            }

            self.convertSamples(
                samplesOrNil ?? [], dataTypeKey: dataTypeKey, unit: unit, includeManualEntry: includeManualEntry
            ) { converted in
                switch converted {
                case let .success(data):
                    result(data)
                case let .failure(error):
                    result(HealthUtilities.flutterError(for: error, operation: "getting health data"))
                }
            }
        }

        healthStore.execute(query)
    }

    /// Gets single health data by UUID
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func getDataByUUID(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? NSDictionary,
              let uuidarg = arguments["uuid"] as? String,
              let dataTypeKey = arguments["dataTypeKey"] as? String
        else {
            result(
                FlutterError(
                    code: "HEALTH_ERROR",
                    message: "Invalid Arguments - UUID or DataTypeKey invalid",
                    details: nil
                )
            )
            return
        }

        let dataUnitKey = arguments["dataUnitKey"] as? String
        let unit = dataUnitKey.flatMap { unitDict[$0] }

        // As in getDataPage: a type this iOS version does not have is not registered.
        guard let dataType = dataTypesDict[dataTypeKey] else {
            result(
                FlutterError(
                    code: "NOT_SUPPORTED",
                    message: "Data type \(dataTypeKey) is not available on this device",
                    details: nil
                )
            )
            return
        }

        if let unitError = incompatibleUnitError(dataType, unit: unit, dataTypeKey: dataTypeKey, unitKey: dataUnitKey) {
            result(unitError)
            return
        }

        guard let uuid = UUID(uuidString: uuidarg) else {
            result(nil)
            return
        }

        let predicate = HKQuery.predicateForObjects(with: [uuid])

        let query = HKSampleQuery(
            sampleType: dataType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, samplesOrNil, error in
            if let error {
                if HealthUtilities.isNoData(error) {
                    result(nil)
                } else {
                    result(HealthUtilities.flutterError(for: error, operation: "getting health data by UUID"))
                }
                return
            }

            self.convertSamples(
                samplesOrNil ?? [], dataTypeKey: dataTypeKey, unit: unit, includeManualEntry: true
            ) { converted in
                switch converted {
                case let .success(data):
                    result(data.first)
                case let .failure(error):
                    result(HealthUtilities.flutterError(for: error, operation: "getting health data by UUID"))
                }
            }
        }

        healthStore.execute(query)
    }
}
