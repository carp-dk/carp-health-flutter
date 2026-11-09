import HealthKit

extension HealthPlugin {
    /// Initialize iOS 13 specific data types
    @available(iOS 13.0, *)
    func initializeIOS13Types() {
        dataTypesDict[HealthConstants.ACTIVE_ENERGY_BURNED] = HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!
        dataTypesDict[HealthConstants.APPLE_STAND_TIME] = HKSampleType.quantityType(forIdentifier: .appleStandTime)!
        dataTypesDict[HealthConstants.AUDIOGRAM] = HKSampleType.audiogramSampleType()
        dataTypesDict[HealthConstants.BASAL_ENERGY_BURNED] = HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!
        dataTypesDict[HealthConstants.BLOOD_GLUCOSE] = HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
        dataTypesDict[HealthConstants.BLOOD_OXYGEN] = HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!
        dataTypesDict[HealthConstants.RESPIRATORY_RATE] = HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
        dataTypesDict[HealthConstants.PERIPHERAL_PERFUSION_INDEX] = HKSampleType.quantityType(forIdentifier: .peripheralPerfusionIndex)!

        dataTypesDict[HealthConstants.BLOOD_PRESSURE_DIASTOLIC] = HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
        dataTypesDict[HealthConstants.BLOOD_PRESSURE_SYSTOLIC] = HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!
        dataTypesDict[HealthConstants.BODY_FAT_PERCENTAGE] = HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!
        dataTypesDict[HealthConstants.LEAN_BODY_MASS] = HKSampleType.quantityType(forIdentifier: .leanBodyMass)!
        dataTypesDict[HealthConstants.BODY_MASS_INDEX] = HKSampleType.quantityType(forIdentifier: .bodyMassIndex)!
        dataTypesDict[HealthConstants.BODY_TEMPERATURE] = HKSampleType.quantityType(forIdentifier: .bodyTemperature)!

        // Initialize nutrition types
        initializeNutritionTypes()

        dataTypesDict[HealthConstants.ELECTRODERMAL_ACTIVITY] = HKSampleType.quantityType(forIdentifier: .electrodermalActivity)!
        dataTypesDict[HealthConstants.FORCED_EXPIRATORY_VOLUME] = HKSampleType.quantityType(forIdentifier: .forcedExpiratoryVolume1)!
        dataTypesDict[HealthConstants.HEART_RATE] = HKSampleType.quantityType(forIdentifier: .heartRate)!
        dataTypesDict[HealthConstants.HEART_RATE_VARIABILITY_SDNN] = HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        dataTypesDict[HealthConstants.HEIGHT] = HKSampleType.quantityType(forIdentifier: .height)!
        dataTypesDict[HealthConstants.INSULIN_DELIVERY] = HKSampleType.quantityType(forIdentifier: .insulinDelivery)!
        dataTypesDict[HealthConstants.RESTING_HEART_RATE] = HKSampleType.quantityType(forIdentifier: .restingHeartRate)!
        dataTypesDict[HealthConstants.STEPS] = HKSampleType.quantityType(forIdentifier: .stepCount)!
        dataTypesDict[HealthConstants.WAIST_CIRCUMFERENCE] = HKSampleType.quantityType(forIdentifier: .waistCircumference)!
        dataTypesDict[HealthConstants.WALKING_HEART_RATE] = HKSampleType.quantityType(forIdentifier: .walkingHeartRateAverage)!
        dataTypesDict[HealthConstants.WEIGHT] = HKSampleType.quantityType(forIdentifier: .bodyMass)!
        dataTypesDict[HealthConstants.DISTANCE_WALKING_RUNNING] = HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!
        dataTypesDict[HealthConstants.DISTANCE_SWIMMING] = HKSampleType.quantityType(forIdentifier: .distanceSwimming)!
        dataTypesDict[HealthConstants.DISTANCE_CYCLING] = HKSampleType.quantityType(forIdentifier: .distanceCycling)!
        dataTypesDict[HealthConstants.FLIGHTS_CLIMBED] = HKSampleType.quantityType(forIdentifier: .flightsClimbed)!
        dataTypesDict[HealthConstants.MINDFULNESS] = HKSampleType.categoryType(forIdentifier: .mindfulSession)!
        dataTypesDict[HealthConstants.SLEEP_AWAKE] = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        dataTypesDict[HealthConstants.SLEEP_DEEP] = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        dataTypesDict[HealthConstants.SLEEP_IN_BED] = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        dataTypesDict[HealthConstants.SLEEP_LIGHT] = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        dataTypesDict[HealthConstants.SLEEP_REM] = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        dataTypesDict[HealthConstants.SLEEP_ASLEEP] = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        dataTypesDict[HealthConstants.MENSTRUATION_FLOW] = HKSampleType.categoryType(forIdentifier: .menstrualFlow)!

        dataTypesDict[HealthConstants.EXERCISE_TIME] = HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!
        dataTypesDict[HealthConstants.WORKOUT] = HKSampleType.workoutType()
        dataTypesDict[HealthConstants.NUTRITION] = HKSampleType.correlationType(forIdentifier: .food)!

        characteristicsTypesDict[HealthConstants.BIRTH_DATE] = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        characteristicsTypesDict[HealthConstants.GENDER] = HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
        characteristicsTypesDict[HealthConstants.BLOOD_TYPE] = HKObjectType.characteristicType(forIdentifier: .bloodType)!
    }

    /// Initialize nutrition types for iOS 13+
    @available(iOS 13.0, *)
    private func initializeNutritionTypes() {
        dataTypesDict[HealthConstants.DIETARY_CARBS_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryCarbohydrates)!
        dataTypesDict[HealthConstants.DIETARY_CAFFEINE] = HKSampleType.quantityType(forIdentifier: .dietaryCaffeine)!
        dataTypesDict[HealthConstants.DIETARY_ENERGY_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
        dataTypesDict[HealthConstants.DIETARY_FATS_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryFatTotal)!
        dataTypesDict[HealthConstants.DIETARY_PROTEIN_CONSUMED] = HKSampleType.quantityType(forIdentifier: .dietaryProtein)!
        dataTypesDict[HealthConstants.DIETARY_FIBER] = HKSampleType.quantityType(forIdentifier: .dietaryFiber)!
        dataTypesDict[HealthConstants.DIETARY_SUGAR] = HKSampleType.quantityType(forIdentifier: .dietarySugar)!
        dataTypesDict[HealthConstants.DIETARY_FAT_MONOUNSATURATED] = HKSampleType.quantityType(forIdentifier: .dietaryFatMonounsaturated)!
        dataTypesDict[HealthConstants.DIETARY_FAT_POLYUNSATURATED] = HKSampleType.quantityType(forIdentifier: .dietaryFatPolyunsaturated)!
        dataTypesDict[HealthConstants.DIETARY_FAT_SATURATED] = HKSampleType.quantityType(forIdentifier: .dietaryFatSaturated)!
        dataTypesDict[HealthConstants.DIETARY_CHOLESTEROL] = HKSampleType.quantityType(forIdentifier: .dietaryCholesterol)!
        dataTypesDict[HealthConstants.DIETARY_VITAMIN_A] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminA)!
        dataTypesDict[HealthConstants.DIETARY_THIAMIN] = HKSampleType.quantityType(forIdentifier: .dietaryThiamin)!
        dataTypesDict[HealthConstants.DIETARY_RIBOFLAVIN] = HKSampleType.quantityType(forIdentifier: .dietaryRiboflavin)!
        dataTypesDict[HealthConstants.DIETARY_NIACIN] = HKSampleType.quantityType(forIdentifier: .dietaryNiacin)!
        dataTypesDict[HealthConstants.DIETARY_PANTOTHENIC_ACID] = HKSampleType.quantityType(forIdentifier: .dietaryPantothenicAcid)!
        dataTypesDict[HealthConstants.DIETARY_VITAMIN_B6] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminB6)!
        dataTypesDict[HealthConstants.DIETARY_BIOTIN] = HKSampleType.quantityType(forIdentifier: .dietaryBiotin)!
        dataTypesDict[HealthConstants.DIETARY_VITAMIN_B12] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminB12)!
        dataTypesDict[HealthConstants.DIETARY_VITAMIN_C] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminC)!
        dataTypesDict[HealthConstants.DIETARY_VITAMIN_D] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminD)!
        dataTypesDict[HealthConstants.DIETARY_VITAMIN_E] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminE)!
        dataTypesDict[HealthConstants.DIETARY_VITAMIN_K] = HKSampleType.quantityType(forIdentifier: .dietaryVitaminK)!
        dataTypesDict[HealthConstants.DIETARY_FOLATE] = HKSampleType.quantityType(forIdentifier: .dietaryFolate)!
        dataTypesDict[HealthConstants.DIETARY_CALCIUM] = HKSampleType.quantityType(forIdentifier: .dietaryCalcium)!
        dataTypesDict[HealthConstants.DIETARY_CHLORIDE] = HKSampleType.quantityType(forIdentifier: .dietaryChloride)!
        dataTypesDict[HealthConstants.DIETARY_IRON] = HKSampleType.quantityType(forIdentifier: .dietaryIron)!
        dataTypesDict[HealthConstants.DIETARY_MAGNESIUM] = HKSampleType.quantityType(forIdentifier: .dietaryMagnesium)!
        dataTypesDict[HealthConstants.DIETARY_PHOSPHORUS] = HKSampleType.quantityType(forIdentifier: .dietaryPhosphorus)!
        dataTypesDict[HealthConstants.DIETARY_POTASSIUM] = HKSampleType.quantityType(forIdentifier: .dietaryPotassium)!
        dataTypesDict[HealthConstants.DIETARY_SODIUM] = HKSampleType.quantityType(forIdentifier: .dietarySodium)!
        dataTypesDict[HealthConstants.DIETARY_ZINC] = HKSampleType.quantityType(forIdentifier: .dietaryZinc)!
        dataTypesDict[HealthConstants.DIETARY_WATER] = HKSampleType.quantityType(forIdentifier: .dietaryWater)!
        dataTypesDict[HealthConstants.DIETARY_CHROMIUM] = HKSampleType.quantityType(forIdentifier: .dietaryChromium)!
        dataTypesDict[HealthConstants.DIETARY_COPPER] = HKSampleType.quantityType(forIdentifier: .dietaryCopper)!
        dataTypesDict[HealthConstants.DIETARY_IODINE] = HKSampleType.quantityType(forIdentifier: .dietaryIodine)!
        dataTypesDict[HealthConstants.DIETARY_MANGANESE] = HKSampleType.quantityType(forIdentifier: .dietaryManganese)!
        dataTypesDict[HealthConstants.DIETARY_MOLYBDENUM] = HKSampleType.quantityType(forIdentifier: .dietaryMolybdenum)!
        dataTypesDict[HealthConstants.DIETARY_SELENIUM] = HKSampleType.quantityType(forIdentifier: .dietarySelenium)!
    }
}
