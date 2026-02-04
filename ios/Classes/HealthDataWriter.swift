import Flutter
import HealthKit
import CoreLocation

/// Class responsible for writing health data to HealthKit
class HealthDataWriter {
    let healthStore: HKHealthStore
    let dataTypesDict: [String: HKSampleType]
    let unitDict: [String: HKUnit]
    let workoutActivityTypeMap: [String: HKWorkoutActivityType]
    private var workoutRouteBuilders: [String: HKWorkoutRouteBuilder] = [:]
    private let workoutRouteBuildersQueue = DispatchQueue(
        label: "com.carp.health.workoutRouteBuilders")
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// - Parameters:
    ///   - healthStore: The HealthKit store
    ///   - dataTypesDict: Dictionary of data types
    ///   - unitDict: Dictionary of units
    ///   - workoutActivityTypeMap: Dictionary of workout activity types
    init(
        healthStore: HKHealthStore, dataTypesDict: [String: HKSampleType],
        unitDict: [String: HKUnit], workoutActivityTypeMap: [String: HKWorkoutActivityType]
    ) {
        self.healthStore = healthStore
        self.dataTypesDict = dataTypesDict
        self.unitDict = unitDict
        self.workoutActivityTypeMap = workoutActivityTypeMap
    }
    
    // MARK: - Workout Route Helpers
    
    private func storeWorkoutRouteBuilder(
        _ builder: HKWorkoutRouteBuilder,
        for identifier: String
    ) {
        workoutRouteBuildersQueue.async {
            self.workoutRouteBuilders[identifier] = builder
        }
    }
    
    private func workoutRouteBuilder(for identifier: String) -> HKWorkoutRouteBuilder? {
        var builder: HKWorkoutRouteBuilder?
        workoutRouteBuildersQueue.sync {
            builder = self.workoutRouteBuilders[identifier]
        }
        return builder
    }
    
    private func removeWorkoutRouteBuilder(for identifier: String) -> HKWorkoutRouteBuilder? {
        var builder: HKWorkoutRouteBuilder?
        workoutRouteBuildersQueue.sync {
            builder = self.workoutRouteBuilders.removeValue(forKey: identifier)
        }
        return builder
    }
    
    private func parseTimestamp(_ value: Any) -> Date? {
        if let milliseconds = value as? NSNumber {
            return Date(timeIntervalSince1970: milliseconds.doubleValue / 1000.0)
        } else if let doubleValue = value as? Double {
            return Date(timeIntervalSince1970: doubleValue / 1000.0)
        } else if let stringValue = value as? String {
            if let date = isoFormatter.date(from: stringValue) {
                return date
            }
            if let doubleValue = Double(stringValue) {
                return Date(timeIntervalSince1970: doubleValue / 1000.0)
            }
        }
        return nil
    }
    
    private func doubleValue(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        } else if let doubleValue = value as? Double {
            return doubleValue
        } else if let stringValue = value as? String {
            return Double(stringValue)
        }
        return nil
    }
    
    private func parseLocations(_ rawLocations: [NSDictionary]) throws -> [CLLocation] {
        return try rawLocations.map { entry in
            guard
                let latitudeValue = doubleValue(from: entry["latitude"]),
                let longitudeValue = doubleValue(from: entry["longitude"]),
                let timestampValue = entry["timestamp"]
            else {
                throw PluginError(message: "Invalid workout route location entry")
            }
            
            let latitude = CLLocationDegrees(latitudeValue)
            let longitude = CLLocationDegrees(longitudeValue)
            
            guard let timestamp = parseTimestamp(timestampValue) else {
                throw PluginError(message: "Invalid workout route timestamp")
            }
            
            let altitude = doubleValue(from: entry["altitude"]) ?? 0
            let horizontalAccuracy = doubleValue(from: entry["horizontalAccuracy"])
                ?? kCLLocationAccuracyHundredMeters
            let verticalAccuracy = doubleValue(from: entry["verticalAccuracy"])
                ?? kCLLocationAccuracyHundredMeters
            let speed = doubleValue(from: entry["speed"]) ?? -1
            let course = doubleValue(from: entry["course"]) ?? -1
            let speedAccuracyValue = doubleValue(from: entry["speedAccuracy"])
            let courseAccuracyValue = doubleValue(from: entry["courseAccuracy"])
            
            if #available(iOS 13.4, *),
                let speedAccuracyValue, let courseAccuracyValue
            {
                return CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    altitude: altitude,
                    horizontalAccuracy: horizontalAccuracy,
                    verticalAccuracy: verticalAccuracy,
                    course: course,
                    courseAccuracy: courseAccuracyValue,
                    speed: speed,
                    speedAccuracy: speedAccuracyValue,
                    timestamp: timestamp
                )
            } else {
                return CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    altitude: altitude,
                    horizontalAccuracy: horizontalAccuracy,
                    verticalAccuracy: verticalAccuracy,
                    course: course,
                    speed: speed,
                    timestamp: timestamp
                )
            }
        }
    }

    /// Writes general health data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeData(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let value = (arguments["value"] as? Double),
            let type = (arguments["dataTypeKey"] as? String),
            let unit = (arguments["dataUnitKey"] as? String),
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber),
            let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        // Handle mindfulness sessions specifically
        if type == HealthConstants.MINDFULNESS {
            try writeMindfulness(call: call, result: result)
            return
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry)
        ]

        let sample: HKObject

        if dataTypesDict[type]!.isKind(of: HKCategoryType.self) {
            sample = HKCategorySample(
                type: dataTypesDict[type] as! HKCategoryType, value: Int(value), start: dateFrom,
                end: dateTo, metadata: metadata)
        } else {
            let quantity = HKQuantity(unit: unitDict[unit]!, doubleValue: value)
            sample = HKQuantitySample(
                type: dataTypesDict[type] as! HKQuantityType, quantity: quantity, start: dateFrom,
                end: dateTo, metadata: metadata)
        }

        healthStore.save(
            sample,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving \(type) Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            })
    }
    
    /// Starts a new workout route builder session.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func startWorkoutRoute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil))
            return
        }
        
        let identifier = UUID().uuidString
        let builder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        storeWorkoutRouteBuilder(builder, for: identifier)
        result(identifier)
    }
    
    /// Inserts a batch of workout route locations into an active builder.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func insertWorkoutRouteData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil))
            return
        }
        
        guard
            let arguments = call.arguments as? NSDictionary,
            let builderId = arguments["builderId"] as? String,
            let rawLocations = arguments["locations"] as? [NSDictionary]
        else {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: "Missing builderId or locations for route insertion",
                    details: nil))
            return
        }
        
        guard let builder = workoutRouteBuilder(for: builderId) else {
            result(
                FlutterError(
                    code: "ROUTE_ERROR",
                    message: "No active workout route builder for identifier \(builderId)",
                    details: nil))
            return
        }
        
        if rawLocations.isEmpty {
            result(true)
            return
        }
        
        let locations: [CLLocation]
        do {
            locations = try parseLocations(rawLocations)
        } catch {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: error.localizedDescription,
                    details: nil))
            return
        }
        
        builder.insertRouteData(locations) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(
                        FlutterError(
                            code: "ROUTE_ERROR",
                            message: "Error inserting workout route data: \(error.localizedDescription)",
                            details: nil))
                } else {
                    result(success)
                }
            }
        }
    }
    
    /// Completes an active workout route builder and associates it with an existing workout.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func finishWorkoutRoute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil))
            return
        }
        
        guard
            let arguments = call.arguments as? NSDictionary,
            let builderId = arguments["builderId"] as? String,
            let workoutUUIDString = arguments["workoutUUID"] as? String,
            let workoutUUID = UUID(uuidString: workoutUUIDString)
        else {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: "Missing builderId or workoutUUID for finishing route",
                    details: nil))
            return
        }
        
        guard let builder = workoutRouteBuilder(for: builderId) else {
            result(
                FlutterError(
                    code: "ROUTE_ERROR",
                    message: "No active workout route builder for identifier \(builderId)",
                    details: nil))
            return
        }
        
        let metadata = arguments["metadata"] as? [String: Any]
        let predicate = HKQuery.predicateForObject(with: workoutUUID)
        let workoutType = HKObjectType.workoutType()
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { [weak self] _, samplesOrNil, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "ROUTE_ERROR",
                            message: "Error fetching workout for route: \(error.localizedDescription)",
                            details: nil))
                }
                return
            }
            
            guard let workout = (samplesOrNil?.first as? HKWorkout) else {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "ROUTE_ERROR",
                            message: "Workout with UUID \(workoutUUIDString) not found",
                            details: nil))
                }
                return
            }
            
            var finalMetadata = metadata ?? [:]
            finalMetadata["workout_uuid"] = workoutUUIDString

            builder.finishRoute(with: workout, metadata: finalMetadata) {
                [weak self] route, finishError in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.removeWorkoutRouteBuilder(for: builderId)
                    if let finishError = finishError {
                        result(
                            FlutterError(
                                code: "ROUTE_ERROR",
                                message:
                                    "Error finishing workout route: \(finishError.localizedDescription)",
                                details: nil))
                    } else if let route = route {
                        result([
                            "uuid": "\(route.uuid)",
                            "startDate":
                                Int(route.startDate.timeIntervalSince1970 * 1000),
                            "endDate":
                                Int(route.endDate.timeIntervalSince1970 * 1000),
                        ])
                    } else {
                        result(
                            FlutterError(
                                code: "ROUTE_ERROR",
                                message: "Workout route builder returned no route",
                                details: nil))
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Discards an active workout route builder session.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func discardWorkoutRoute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil))
            return
        }
        
        guard
            let arguments = call.arguments as? NSDictionary,
            let builderId = arguments["builderId"] as? String
        else {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: "Missing builderId for discarding workout route",
                    details: nil))
            return
        }
        
        guard let builder = removeWorkoutRouteBuilder(for: builderId) else {
            result(false)
            return
        }
        
        builder.discard()
        result(true)
    }

    /// Writes audiogram data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeAudiogram(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let frequencies = (arguments["frequencies"] as? [Double]),
            let leftEarSensitivities = (arguments["leftEarSensitivities"] as? [Double]),
            let rightEarSensitivities = (arguments["rightEarSensitivities"] as? [Double]),
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber)
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        var sensitivityPoints = [HKAudiogramSensitivityPoint]()

        for index in 0...frequencies.count - 1 {
            let frequency = HKQuantity(unit: HKUnit.hertz(), doubleValue: frequencies[index])
            let dbUnit = HKUnit.decibelHearingLevel()
            let left = HKQuantity(unit: dbUnit, doubleValue: leftEarSensitivities[index])
            let right = HKQuantity(unit: dbUnit, doubleValue: rightEarSensitivities[index])
            let sensitivityPoint = try HKAudiogramSensitivityPoint(
                frequency: frequency, leftEarSensitivity: left, rightEarSensitivity: right)
            sensitivityPoints.append(sensitivityPoint)
        }

        let audiogram: HKAudiogramSample
        let metadataReceived = (arguments["metadata"] as? [String: Any]?)

        if (metadataReceived) != nil {
            guard let deviceName = metadataReceived?!["HKDeviceName"] as? String else { return }
            guard let externalUUID = metadataReceived?!["HKExternalUUID"] as? String else { return }

            audiogram = HKAudiogramSample(
                sensitivityPoints: sensitivityPoints, start: dateFrom, end: dateTo,
                metadata: [
                    HKMetadataKeyDeviceName: deviceName, HKMetadataKeyExternalUUID: externalUUID,
                ])

        } else {
            audiogram = HKAudiogramSample(
                sensitivityPoints: sensitivityPoints, start: dateFrom, end: dateTo, metadata: nil)
        }

        healthStore.save(
            audiogram,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving Audiogram. Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            })
    }

    /// Writes blood pressure data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeBloodPressure(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let systolic = (arguments["systolic"] as? Double),
            let diastolic = (arguments["diastolic"] as? Double),
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber),
            let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(message: "Invalid Arguments")
        }
        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry)
        ]

        let systolic_sample = HKQuantitySample(
            type: HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            quantity: HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: systolic),
            start: dateFrom, end: dateTo, metadata: metadata)
        let diastolic_sample = HKQuantitySample(
            type: HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            quantity: HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: diastolic),
            start: dateFrom, end: dateTo, metadata: metadata)
        let bpCorrelationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!
        let bpCorrelation = Set(arrayLiteral: systolic_sample, diastolic_sample)
        let blood_pressure_sample = HKCorrelation(
            type: bpCorrelationType, start: dateFrom, end: dateTo, objects: bpCorrelation)

        healthStore.save(
            [blood_pressure_sample],
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving Blood Pressure Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            })
    }

    /// Writes meal nutrition data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeMeal(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let name = (arguments["name"] as? String?),
            let startTime = (arguments["start_time"] as? NSNumber),
            let endTime = (arguments["end_time"] as? NSNumber),
            let mealType = (arguments["meal_type"] as? String?),
            let recordingMethod = arguments["recordingMethod"] as? Int
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let mealTypeString = mealType ?? "UNKNOWN"

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue

        var metadata =
            [
                "HKFoodMeal": mealTypeString,
                HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
            ] as [String: Any]
        if name != nil {
            metadata[HKMetadataKeyFoodType] = "\(name!)"
        }

        var nutrition = Set<HKSample>()
        for (key, identifier) in HealthConstants.NUTRITION_KEYS {
            let value = arguments[key] as? Double
            guard let unwrappedValue = value else { continue }
            let unit =
                key == "calories"
                ? HKUnit.kilocalorie()
                : key == "water" ? HKUnit.literUnit(with: .milli) : HKUnit.gram()
            let nutritionSample = HKQuantitySample(
                type: HKSampleType.quantityType(forIdentifier: identifier)!,
                quantity: HKQuantity(unit: unit, doubleValue: unwrappedValue), start: dateFrom,
                end: dateTo, metadata: metadata)
            nutrition.insert(nutritionSample)
        }

        if #available(iOS 15.0, *) {
            let type = HKCorrelationType.correlationType(
                forIdentifier: HKCorrelationTypeIdentifier.food)!
            let meal = HKCorrelation(
                type: type, start: dateFrom, end: dateTo, objects: nutrition, metadata: metadata)

            healthStore.save(
                meal,
                withCompletion: { (success, error) in
                    if let err = error {
                        print("Error Saving Meal Sample: \(err.localizedDescription)")
                    }
                    DispatchQueue.main.async {
                        result(success)
                    }
                })
        } else {
            result(false)
        }
    }

    /// Writes insulin delivery data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeInsulinDelivery(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let units = (arguments["units"] as? Double),
            let reason = (arguments["reason"] as? NSNumber),
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber)
        else {
            throw PluginError(message: "Invalid Arguments")
        }
        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let type = HKSampleType.quantityType(forIdentifier: .insulinDelivery)!
        let quantity = HKQuantity(unit: HKUnit.internationalUnit(), doubleValue: units)
        let metadata = [HKMetadataKeyInsulinDeliveryReason: reason]

        let insulin_sample = HKQuantitySample(
            type: type, quantity: quantity, start: dateFrom, end: dateTo, metadata: metadata)

        healthStore.save(
            insulin_sample,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving Insulin Delivery Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            })
    }

    /// Writes menstruation flow data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeMenstruationFlow(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let flow = (arguments["value"] as? Int),
            let endTime = (arguments["endTime"] as? NSNumber),
            let isStartOfCycle = (arguments["isStartOfCycle"] as? NSNumber),
            let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(
                message: "Invalid Arguments - value, startTime, endTime or isStartOfCycle invalid")
        }
        guard let menstrualFlowType = HKCategoryValueMenstrualFlow(rawValue: flow) else {
            throw PluginError(message: "Invalid Menstrual Flow Type")
        }

        let dateTime = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue

        guard let categoryType = HKSampleType.categoryType(forIdentifier: .menstrualFlow) else {
            throw PluginError(message: "Invalid Menstrual Flow Type")
        }

        let metadata =
            [
                HKMetadataKeyMenstrualCycleStart: isStartOfCycle,
                HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry),
            ] as [String: Any]

        let sample = HKCategorySample(
            type: categoryType,
            value: menstrualFlowType.rawValue,
            start: dateTime,
            end: dateTime,
            metadata: metadata
        )

        healthStore.save(
            sample,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving Menstruation Flow Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            })
    }

    /// Writes mindfulness session data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeMindfulness(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber),
            let recordingMethod = (arguments["recordingMethod"] as? Int)
        else {
            throw PluginError(message: "Invalid Arguments")
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let isManualEntry = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: NSNumber(value: isManualEntry)
        ]

        guard let categoryType = HKSampleType.categoryType(forIdentifier: .mindfulSession) else {
            throw PluginError(message: "Invalid Mindfulness Session Type")
        }

        // The duration is tracked by the start and end dates, not by the value
        let sample = HKCategorySample(
            type: categoryType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: dateFrom,
            end: dateTo,
            metadata: metadata
        )

        healthStore.save(
            sample,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving Mindfulness Session: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            })
    }

    /// Writes workout data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeWorkoutData(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
            let activityType = (arguments["activityType"] as? String),
            let startTime = (arguments["startTime"] as? NSNumber),
            let endTime = (arguments["endTime"] as? NSNumber),
            let activityTypeValue = workoutActivityTypeMap[activityType]
        else {
            throw PluginError(
                message: "Invalid Arguments - activityType, startTime or endTime invalid")
        }

        var totalEnergyBurned: HKQuantity?
        var totalDistance: HKQuantity? = nil

        // Handle optional arguments
        if let teb = (arguments["totalEnergyBurned"] as? Double) {
            totalEnergyBurned = HKQuantity(
                unit: unitDict[(arguments["totalEnergyBurnedUnit"] as! String)]!, doubleValue: teb)
        }
        if let td = (arguments["totalDistance"] as? Double) {
            totalDistance = HKQuantity(
                unit: unitDict[(arguments["totalDistanceUnit"] as! String)]!, doubleValue: td)
        }

        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let workout = HKWorkout(
            activityType: activityTypeValue,
            start: dateFrom,
            end: dateTo,
            duration: dateTo.timeIntervalSince(dateFrom),
            totalEnergyBurned: totalEnergyBurned ?? nil,
            totalDistance: totalDistance ?? nil,
            metadata: nil
        )

        healthStore.save(
            workout,
            withCompletion: { (success, error) in
                if let err = error {
                    print("Error Saving Workout. Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            })
    }
}
