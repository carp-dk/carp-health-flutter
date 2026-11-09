import HealthKit

extension HealthPlugin {
    /// Initialize iOS 11 specific data types
    @available(iOS 11.0, *)
    func initializeIOS11Types() {
        dataTypesDict[HealthConstants.APPLE_STAND_HOUR] = HKSampleType.categoryType(forIdentifier: .appleStandHour)!
        dataTypesDict[HealthConstants.WORKOUT_ROUTE] = HKSeriesType.workoutRoute()

        dataQuantityTypesDict[HealthConstants.ACTIVE_ENERGY_BURNED] = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        dataQuantityTypesDict[HealthConstants.BASAL_ENERGY_BURNED] = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
        dataQuantityTypesDict[HealthConstants.BLOOD_GLUCOSE] = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
        dataQuantityTypesDict[HealthConstants.BLOOD_OXYGEN] = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        dataQuantityTypesDict[HealthConstants.BLOOD_PRESSURE_DIASTOLIC] = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!
        dataQuantityTypesDict[HealthConstants.BLOOD_PRESSURE_SYSTOLIC] = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!
        dataQuantityTypesDict[HealthConstants.BODY_FAT_PERCENTAGE] = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        dataQuantityTypesDict[HealthConstants.LEAN_BODY_MASS] = HKSampleType.quantityType(forIdentifier: .leanBodyMass)!
        dataQuantityTypesDict[HealthConstants.BODY_MASS_INDEX] = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)!
        dataQuantityTypesDict[HealthConstants.BODY_TEMPERATURE] = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!

        // Initialize nutrition quantity types
        initializeNutritionQuantityTypes()

        dataQuantityTypesDict[HealthConstants.ELECTRODERMAL_ACTIVITY] = HKQuantityType.quantityType(forIdentifier: .electrodermalActivity)!
        dataQuantityTypesDict[HealthConstants.FORCED_EXPIRATORY_VOLUME] = HKQuantityType.quantityType(forIdentifier: .forcedExpiratoryVolume1)!
        dataQuantityTypesDict[HealthConstants.HEART_RATE] = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        dataQuantityTypesDict[HealthConstants.HEART_RATE_VARIABILITY_SDNN] = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        dataQuantityTypesDict[HealthConstants.HEIGHT] = HKQuantityType.quantityType(forIdentifier: .height)!
        dataQuantityTypesDict[HealthConstants.RESTING_HEART_RATE] = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        dataQuantityTypesDict[HealthConstants.STEPS] = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        dataQuantityTypesDict[HealthConstants.WAIST_CIRCUMFERENCE] = HKQuantityType.quantityType(forIdentifier: .waistCircumference)!
        dataQuantityTypesDict[HealthConstants.WALKING_HEART_RATE] = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)!
        dataQuantityTypesDict[HealthConstants.WEIGHT] = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        dataQuantityTypesDict[HealthConstants.DISTANCE_WALKING_RUNNING] = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        dataQuantityTypesDict[HealthConstants.DISTANCE_SWIMMING] = HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!
        dataQuantityTypesDict[HealthConstants.DISTANCE_CYCLING] = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        dataQuantityTypesDict[HealthConstants.FLIGHTS_CLIMBED] = HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    }

    /// Initialize nutrition quantity types
    @available(iOS 11.0, *)
    private func initializeNutritionQuantityTypes() {
        dataQuantityTypesDict[HealthConstants.DIETARY_CARBS_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryCarbohydrates)!
        dataQuantityTypesDict[HealthConstants.DIETARY_CAFFEINE] = HKSampleType.quantityType(forIdentifier: .dietaryCaffeine)!
        dataQuantityTypesDict[HealthConstants.DIETARY_ENERGY_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
        dataQuantityTypesDict[HealthConstants.DIETARY_FATS_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryFatTotal)!
        dataQuantityTypesDict[HealthConstants.DIETARY_PROTEIN_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryProtein)!
        dataQuantityTypesDict[HealthConstants.DIETARY_FIBER] = HKSampleType.quantityType(forIdentifier: .dietaryFiber)!
        dataQuantityTypesDict[HealthConstants.DIETARY_SUGAR] = HKSampleType.quantityType(forIdentifier: .dietarySugar)!
        dataQuantityTypesDict[HealthConstants.DIETARY_FAT_MONOUNSATURATED] = HKSampleType.quantityType(forIdentifier: .dietaryFatMonounsaturated)!
        dataQuantityTypesDict[HealthConstants.DIETARY_FAT_POLYUNSATURATED] = HKSampleType.quantityType(forIdentifier: .dietaryFatPolyunsaturated)!
        dataQuantityTypesDict[HealthConstants.DIETARY_FAT_SATURATED] = HKSampleType.quantityType(forIdentifier: .dietaryFatSaturated)!
        dataQuantityTypesDict[HealthConstants.DIETARY_CHOLESTEROL] = HKSampleType.quantityType(forIdentifier: .dietaryCholesterol)!
        dataQuantityTypesDict[HealthConstants.DIETARY_VITAMIN_A] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminA)!
        dataQuantityTypesDict[HealthConstants.DIETARY_THIAMIN] = HKSampleType.quantityType(forIdentifier: .dietaryThiamin)!
        dataQuantityTypesDict[HealthConstants.DIETARY_RIBOFLAVIN] = HKSampleType.quantityType(forIdentifier: .dietaryRiboflavin)!
        dataQuantityTypesDict[HealthConstants.DIETARY_NIACIN] = HKSampleType.quantityType(forIdentifier: .dietaryNiacin)!
        dataQuantityTypesDict[HealthConstants.DIETARY_PANTOTHENIC_ACID] = HKSampleType.quantityType(forIdentifier: .dietaryPantothenicAcid)!
        dataQuantityTypesDict[HealthConstants.DIETARY_VITAMIN_B6] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminB6)!
        dataQuantityTypesDict[HealthConstants.DIETARY_BIOTIN] = HKSampleType.quantityType(forIdentifier: .dietaryBiotin)!
        dataQuantityTypesDict[HealthConstants.DIETARY_VITAMIN_B12] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminB12)!
        dataQuantityTypesDict[HealthConstants.DIETARY_VITAMIN_C] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminC)!
        dataQuantityTypesDict[HealthConstants.DIETARY_VITAMIN_D] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminD)!
        dataQuantityTypesDict[HealthConstants.DIETARY_VITAMIN_E] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminE)!
        dataQuantityTypesDict[HealthConstants.DIETARY_VITAMIN_K] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminK)!
        dataQuantityTypesDict[HealthConstants.DIETARY_FOLATE] = HKSampleType.quantityType(forIdentifier: .dietaryFolate)!
        dataQuantityTypesDict[HealthConstants.DIETARY_CALCIUM] = HKSampleType.quantityType(forIdentifier: .dietaryCalcium)!
        dataQuantityTypesDict[HealthConstants.DIETARY_CHLORIDE] = HKSampleType.quantityType(forIdentifier: .dietaryChloride)!
        dataQuantityTypesDict[HealthConstants.DIETARY_IRON] = HKSampleType.quantityType(forIdentifier: .dietaryIron)!
        dataQuantityTypesDict[HealthConstants.DIETARY_MAGNESIUM] = HKSampleType.quantityType(forIdentifier: .dietaryMagnesium)!
        dataQuantityTypesDict[HealthConstants.DIETARY_PHOSPHORUS] = HKSampleType.quantityType(forIdentifier: .dietaryPhosphorus)!
        dataQuantityTypesDict[HealthConstants.DIETARY_POTASSIUM] = HKSampleType.quantityType(forIdentifier: .dietaryPotassium)!
        dataQuantityTypesDict[HealthConstants.DIETARY_SODIUM] = HKSampleType.quantityType(forIdentifier: .dietarySodium)!
        dataQuantityTypesDict[HealthConstants.DIETARY_ZINC] = HKSampleType.quantityType(forIdentifier: .dietaryZinc)!
        dataQuantityTypesDict[HealthConstants.DIETARY_WATER] = HKSampleType.quantityType(forIdentifier: .dietaryWater)!
        dataQuantityTypesDict[HealthConstants.DIETARY_CHROMIUM] = HKSampleType.quantityType(forIdentifier: .dietaryChromium)!
        dataQuantityTypesDict[HealthConstants.DIETARY_COPPER] = HKSampleType.quantityType(forIdentifier: .dietaryCopper)!
        dataQuantityTypesDict[HealthConstants.DIETARY_IODINE] = HKSampleType.quantityType(forIdentifier: .dietaryIodine)!
        dataQuantityTypesDict[HealthConstants.DIETARY_MANGANESE] = HKSampleType.quantityType(forIdentifier: .dietaryManganese)!
        dataQuantityTypesDict[HealthConstants.DIETARY_MOLYBDENUM] = HKSampleType.quantityType(forIdentifier: .dietaryMolybdenum)!
        dataQuantityTypesDict[HealthConstants.DIETARY_SELENIUM] = HKSampleType.quantityType(forIdentifier: .dietarySelenium)!
    }
}
