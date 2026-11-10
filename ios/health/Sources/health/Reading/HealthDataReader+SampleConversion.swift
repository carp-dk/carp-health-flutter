import HealthKit

extension HealthDataReader {
    /// Converts samples of one data type to the maps the Dart side parses, in the samples' order.
    /// ECGs and workout routes take one more query per sample (voltages, locations); if one of
    /// those fails, the conversion fails instead of dropping the sample.
    func convertSamples(
        _ samples: [HKSample], dataTypeKey: String, unit: HKUnit?, includeManualEntry: Bool,
        completion: @escaping (Result<[Any], Error>) -> Void
    ) {
        if dataTypeKey == HealthConstants.WORKOUT_ROUTE {
            workoutRouteDictionaries(
                samples.compactMap { $0 as? HKWorkoutRoute }, includeManualEntry: includeManualEntry,
                completion: completion
            )
        } else if dataTypeKey == HealthConstants.ELECTROCARDIOGRAM {
            if #available(iOS 14.0, *) {
                ecgDictionaries(samples.compactMap { $0 as? HKElectrocardiogram }, completion: completion)
            } else {
                print("Error getting ECG - only available on iOS 14.0 and above!")
                completion(.success([]))
            }
        } else {
            completion(.success(sampleDictionaries(samples, dataTypeKey: dataTypeKey, unit: unit)))
        }
    }

    /// Builds the maps of samples that need no further query.
    private func sampleDictionaries(_ samples: [HKSample], dataTypeKey: String, unit: HKUnit?) -> [Any] {
        if let quantitySamples = samples as? [HKQuantitySample] {
            return quantityDictionaries(quantitySamples, unit: unit)
        } else if let categorySamples = samples as? [HKCategorySample] {
            return categoryDictionaries(categorySamples, dataTypeKey: dataTypeKey)
        } else if let workoutSamples = samples as? [HKWorkout] {
            return workoutDictionaries(workoutSamples)
        } else if let audiogramSamples = samples as? [HKAudiogramSample] {
            return audiogramDictionaries(audiogramSamples)
        } else if let nutritionSamples = samples as? [HKCorrelation] {
            return nutritionDictionaries(nutritionSamples)
        }
        return []
    }

    private func quantityDictionaries(_ samples: [HKQuantitySample], unit: HKUnit?) -> [NSDictionary] {
        samples.map { sample -> NSDictionary in
            [
                "uuid": "\(sample.uuid)",
                "value": sample.quantity.doubleValue(
                    for: unit ?? HKUnit.internationalUnit()
                ),
                "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                "source_id": sample.sourceRevision.source.bundleIdentifier,
                "source_name": sample.sourceRevision.source.name,
                "device_model": sample.device?.model as Any,
                "recording_method":
                    (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
                    ? HealthConstants.RecordingMethod.manual.rawValue
                    : HealthConstants.RecordingMethod.automatic.rawValue,
                "dataUnitKey": unit?.unitString as Any,
                "metadata": HealthUtilities.sanitizeMetadata(sample.metadata),
            ]
        }
    }

    private func categoryDictionaries(_ samples: [HKCategorySample], dataTypeKey: String) -> [NSDictionary] {
        // The query already filters by value; this keeps the result right for any other caller.
        var categorySamples = samples
        if let values = CategoryValues(dataTypeKey) {
            categorySamples = categorySamples.filter { values.contains($0.value) }
        }

        return categorySamples.map { sample -> NSDictionary in
            [
                "uuid": "\(sample.uuid)",
                "value": sample.value,
                "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                "source_id": sample.sourceRevision.source.bundleIdentifier,
                "source_name": sample.sourceRevision.source.name,
                "device_model": sample.device?.model as Any,
                "recording_method":
                    (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
                    ? HealthConstants.RecordingMethod.manual.rawValue
                    : HealthConstants.RecordingMethod.automatic.rawValue,
                "metadata": HealthUtilities.sanitizeMetadata(sample.metadata),
            ]
        }
    }

    /// The name a read gives [workout] (HealthWorkoutActivityType on the Dart side): the name of its
    /// type, refined by its metadata, e.g. RUNNING_TREADMILL for an indoor run.
    func workoutActivityName(of workout: HKWorkout) -> String? {
        workoutActivityNames.name(of: workout.workoutActivityType, metadata: workout.metadata)
    }

    private func workoutDictionaries(_ samples: [HKWorkout]) -> [NSDictionary] {
        samples.map { sample -> NSDictionary in
            let dictionary: [String: Any] = [
                "uuid": "\(sample.uuid)",
                "workoutActivityType": workoutActivityName(of: sample) as Any,
                "totalEnergyBurned": sample.totalEnergyBurned?.doubleValue(
                    for: HKUnit.kilocalorie()
                ) as Any,
                "totalEnergyBurnedUnit": "KILOCALORIE",
                "totalDistance": sample.totalDistance?.doubleValue(for: HKUnit.meter()) as Any,
                "totalDistanceUnit": "METER",
                "totalFlightsClimbed": sample.totalFlightsClimbed?.doubleValue(for: HKUnit.count()) as Any,
                "totalSwimmingStrokeCount": sample.totalSwimmingStrokeCount?.doubleValue(
                    for: HKUnit.count()
                ) as Any,
                "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                "source_id": sample.sourceRevision.source.bundleIdentifier,
                "source_name": sample.sourceRevision.source.name,
                "device_model": sample.device?.model as Any,
                "recording_method":
                    (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
                    ? HealthConstants.RecordingMethod.manual.rawValue
                    : HealthConstants.RecordingMethod.automatic.rawValue,
                "workout_type": workoutActivityName(of: sample) ?? "OTHER",
                "total_distance": sample.totalDistance != nil
                    ? Int(sample.totalDistance!.doubleValue(for: HKUnit.meter())) : 0,
                "total_energy_burned": sample.totalEnergyBurned != nil
                    ? Int(sample.totalEnergyBurned!.doubleValue(for: HKUnit.kilocalorie()))
                    : 0,
            ]
            return dictionary.merging(workoutDetails(of: sample)) { value, _ in value } as NSDictionary
        }
    }

    private func audiogramDictionaries(_ samples: [HKAudiogramSample]) -> [NSDictionary] {
        samples.map { sample -> NSDictionary in
            var frequencies = [Double]()
            // NSNull (null on the Dart side) for an ear that was not tested at that frequency.
            var leftEarSensitivities = [Any]()
            var rightEarSensitivities = [Any]()
            for samplePoint in sample.sensitivityPoints {
                frequencies.append(samplePoint.frequency.doubleValue(for: HKUnit.hertz()))
                let sensitivities = earSensitivities(of: samplePoint)
                leftEarSensitivities.append(decibelsOrNull(sensitivities.left))
                rightEarSensitivities.append(decibelsOrNull(sensitivities.right))
            }
            return [
                "uuid": "\(sample.uuid)",
                "frequencies": frequencies,
                "leftEarSensitivities": leftEarSensitivities,
                "rightEarSensitivities": rightEarSensitivities,
                "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                "source_id": sample.sourceRevision.source.bundleIdentifier,
                "source_name": sample.sourceRevision.source.name,
                "device_model": sample.device?.model as Any,
            ]
        }
    }

    /// The sensitivities of a point's ears, nil for an ear without a test at the point's frequency.
    func earSensitivities(
        of point: HKAudiogramSensitivityPoint
    ) -> (left: HKQuantity?, right: HKQuantity?) {
        if #available(iOS 18.1, *) {
            // HealthKit allows one test per ear and only air conduction tests so far: the tests
            // the deprecated properties below return.
            return (
                point.tests.first { $0.side == .left && $0.type == .air }?.sensitivity,
                point.tests.first { $0.side == .right && $0.type == .air }?.sensitivity
            )
        }
        return (point.leftEarSensitivity, point.rightEarSensitivity)
    }

    private func decibelsOrNull(_ sensitivity: HKQuantity?) -> Any {
        sensitivity?.doubleValue(for: HKUnit.decibelHearingLevel()) ?? NSNull()
    }

    private func nutritionDictionaries(_ correlations: [HKCorrelation]) -> [[String: Any?]] {
        var foods: [[String: Any?]] = []
        for food in correlations {
            let name = food.metadata?[HKMetadataKeyFoodType] as? String
            let mealType = food.metadata?["HKFoodMeal"]
            let samples = food.objects
            if let sample = samples.first as? HKQuantitySample {
                var sampleDict = [
                    "uuid": "\(sample.uuid)",
                    "name": name,
                    "meal_type": mealType,
                    "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                    "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                    "source_id": sample.sourceRevision.source.bundleIdentifier,
                    "source_name": sample.sourceRevision.source.name,
                    "device_model": sample.device?.model,
                    "recording_method":
                        (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
                        ? HealthConstants.RecordingMethod.manual.rawValue
                        : HealthConstants.RecordingMethod.automatic.rawValue,
                ]
                for sample in samples {
                    if let quantitySample = sample as? HKQuantitySample {
                        for (key, identifier) in HealthConstants.NUTRITION_KEYS {
                            if quantitySample.quantityType
                                == HKObjectType.quantityType(forIdentifier: identifier)
                            {
                                let unit =
                                    key == "calories"
                                        ? HKUnit.kilocalorie()
                                        : key == "water"
                                        ? HKUnit.literUnit(with: .milli) : HKUnit.gram()
                                sampleDict[key] = quantitySample.quantity.doubleValue(
                                    for: unit
                                )
                            }
                        }
                    }
                }
                foods.append(sampleDict)
            }
        }
        return foods
    }
}
