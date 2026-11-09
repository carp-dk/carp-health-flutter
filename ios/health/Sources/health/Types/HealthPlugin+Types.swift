import HealthKit

extension HealthPlugin {
    /// Initialize all the health data types, unit dictionaries, and other required data structures
    func initializeTypes() {
        // init units
        unitDict[HealthConstants.GRAM] = HKUnit.gram()
        unitDict[HealthConstants.KILOGRAM] = HKUnit.gramUnit(with: .kilo)
        unitDict[HealthConstants.OUNCE] = HKUnit.ounce()
        unitDict[HealthConstants.POUND] = HKUnit.pound()
        unitDict[HealthConstants.STONE] = HKUnit.stone()
        unitDict[HealthConstants.METER] = HKUnit.meter()
        unitDict[HealthConstants.CENTIMETER] = HKUnit.meterUnit(with: .centi)
        unitDict[HealthConstants.INCH] = HKUnit.inch()
        unitDict[HealthConstants.FOOT] = HKUnit.foot()
        unitDict[HealthConstants.YARD] = HKUnit.yard()
        unitDict[HealthConstants.MILE] = HKUnit.mile()
        unitDict[HealthConstants.LITER] = HKUnit.liter()
        unitDict[HealthConstants.MILLILITER] = HKUnit.literUnit(with: .milli)
        unitDict[HealthConstants.FLUID_OUNCE_US] = HKUnit.fluidOunceUS()
        unitDict[HealthConstants.FLUID_OUNCE_IMPERIAL] = HKUnit.fluidOunceImperial()
        unitDict[HealthConstants.CUP_US] = HKUnit.cupUS()
        unitDict[HealthConstants.CUP_IMPERIAL] = HKUnit.cupImperial()
        unitDict[HealthConstants.PINT_US] = HKUnit.pintUS()
        unitDict[HealthConstants.PINT_IMPERIAL] = HKUnit.pintImperial()
        unitDict[HealthConstants.PASCAL] = HKUnit.pascal()
        unitDict[HealthConstants.MILLIMETER_OF_MERCURY] = HKUnit.millimeterOfMercury()
        unitDict[HealthConstants.CENTIMETER_OF_WATER] = HKUnit.centimeterOfWater()
        unitDict[HealthConstants.ATMOSPHERE] = HKUnit.atmosphere()
        unitDict[HealthConstants.DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL] = HKUnit.decibelAWeightedSoundPressureLevel()
        unitDict[HealthConstants.SECOND] = HKUnit.second()
        unitDict[HealthConstants.MILLISECOND] = HKUnit.secondUnit(with: .milli)
        unitDict[HealthConstants.MINUTE] = HKUnit.minute()
        unitDict[HealthConstants.HOUR] = HKUnit.hour()
        unitDict[HealthConstants.DAY] = HKUnit.day()
        unitDict[HealthConstants.JOULE] = HKUnit.joule()
        unitDict[HealthConstants.KILOCALORIE] = HKUnit.kilocalorie()
        unitDict[HealthConstants.LARGE_CALORIE] = HKUnit.largeCalorie()
        unitDict[HealthConstants.SMALL_CALORIE] = HKUnit.smallCalorie()
        unitDict[HealthConstants.DEGREE_CELSIUS] = HKUnit.degreeCelsius()
        unitDict[HealthConstants.DEGREE_FAHRENHEIT] = HKUnit.degreeFahrenheit()
        unitDict[HealthConstants.KELVIN] = HKUnit.kelvin()
        unitDict[HealthConstants.DECIBEL_HEARING_LEVEL] = HKUnit.decibelHearingLevel()
        unitDict[HealthConstants.HERTZ] = HKUnit.hertz()
        unitDict[HealthConstants.SIEMEN] = HKUnit.siemen()
        unitDict[HealthConstants.INTERNATIONAL_UNIT] = HKUnit.internationalUnit()
        unitDict[HealthConstants.COUNT] = HKUnit.count()
        unitDict[HealthConstants.PERCENT] = HKUnit.percent()
        unitDict[HealthConstants.BEATS_PER_MINUTE] = HKUnit(from: "count/min")
        unitDict[HealthConstants.RESPIRATIONS_PER_MINUTE] = HKUnit(from: "count/min")
        unitDict[HealthConstants.MILLIGRAM_PER_DECILITER] = HKUnit(from: "mg/dL")
        unitDict[HealthConstants.MILLIMOLES_PER_LITER] = HKUnit.moleUnit(
            with: .milli, molarMass: HKUnitMolarMassBloodGlucose
        ).unitDivided(by: .liter())
        unitDict[HealthConstants.METER_PER_SECOND] = HKUnit(from: "m/s")
        unitDict[HealthConstants.UNKNOWN_UNIT] = HKUnit(from: "")
        unitDict[HealthConstants.NO_UNIT] = HKUnit(from: "")

        // init workout activity types
        initializeWorkoutTypes()

        nutritionList = [
            HealthConstants.DIETARY_ENERGY_CONSUMED,
            HealthConstants.DIETARY_CARBS_CONSUMED,
            HealthConstants.DIETARY_PROTEIN_CONSUMED,
            HealthConstants.DIETARY_FATS_CONSUMED,
            HealthConstants.DIETARY_CAFFEINE,
            HealthConstants.DIETARY_FIBER,
            HealthConstants.DIETARY_SUGAR,
            HealthConstants.DIETARY_FAT_MONOUNSATURATED,
            HealthConstants.DIETARY_FAT_POLYUNSATURATED,
            HealthConstants.DIETARY_FAT_SATURATED,
            HealthConstants.DIETARY_CHOLESTEROL,
            HealthConstants.DIETARY_VITAMIN_A,
            HealthConstants.DIETARY_THIAMIN,
            HealthConstants.DIETARY_RIBOFLAVIN,
            HealthConstants.DIETARY_NIACIN,
            HealthConstants.DIETARY_PANTOTHENIC_ACID,
            HealthConstants.DIETARY_VITAMIN_B6,
            HealthConstants.DIETARY_BIOTIN,
            HealthConstants.DIETARY_VITAMIN_B12,
            HealthConstants.DIETARY_VITAMIN_C,
            HealthConstants.DIETARY_VITAMIN_D,
            HealthConstants.DIETARY_VITAMIN_E,
            HealthConstants.DIETARY_VITAMIN_K,
            HealthConstants.DIETARY_FOLATE,
            HealthConstants.DIETARY_CALCIUM,
            HealthConstants.DIETARY_CHLORIDE,
            HealthConstants.DIETARY_IRON,
            HealthConstants.DIETARY_MAGNESIUM,
            HealthConstants.DIETARY_PHOSPHORUS,
            HealthConstants.DIETARY_POTASSIUM,
            HealthConstants.DIETARY_SODIUM,
            HealthConstants.DIETARY_ZINC,
            HealthConstants.DIETARY_WATER,
            HealthConstants.DIETARY_CHROMIUM,
            HealthConstants.DIETARY_COPPER,
            HealthConstants.DIETARY_IODINE,
            HealthConstants.DIETARY_MANGANESE,
            HealthConstants.DIETARY_MOLYBDENUM,
            HealthConstants.DIETARY_SELENIUM,
        ]

        // Set up iOS 11 specific types (ordinary health data quantity types)
        if #available(iOS 11.0, *) {
            initializeIOS11Types()
            healthDataQuantityTypes = Array(dataQuantityTypesDict.values)
        }

        // Set up heart rate data types specific to the apple watch, requires iOS 12
        if #available(iOS 12.2, *) {
            initializeIOS12Types()
        }

        // Set up iOS 13 specific types (ordinary health data types)
        if #available(iOS 13.0, *) {
            initializeIOS13Types()
            healthDataTypes = Array(dataTypesDict.values)
            characteristicsDataTypes = Array(characteristicsTypesDict.values)
        }

        if #available(iOS 13.6, *) {
            initializeIOS13_6Types()
        }

        if #available(iOS 14.0, *) {
            initializeIOS14Types()
        }

        if #available(iOS 16.0, *) {
            initializeIOS16Types()
        }

        // Concatenate heart events, headache and health data types (both may be empty)
        allDataTypes = Set(heartRateEventTypes + healthDataTypes)
        allDataTypes = allDataTypes.union(headacheType)
    }

    /// Initialize iOS 12 specific data types
    @available(iOS 12.2, *)
    private func initializeIOS12Types() {
        dataTypesDict[HealthConstants.HIGH_HEART_RATE_EVENT] = HKSampleType.categoryType(forIdentifier: .highHeartRateEvent)!
        dataTypesDict[HealthConstants.LOW_HEART_RATE_EVENT] = HKSampleType.categoryType(forIdentifier: .lowHeartRateEvent)!
        dataTypesDict[HealthConstants.IRREGULAR_HEART_RATE_EVENT] = HKSampleType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!

        heartRateEventTypes = Set([
            HKSampleType.categoryType(forIdentifier: .highHeartRateEvent)!,
            HKSampleType.categoryType(forIdentifier: .lowHeartRateEvent)!,
            HKSampleType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!,
        ])
    }

    /// Initialize iOS 13.6 specific data types
    @available(iOS 13.6, *)
    private func initializeIOS13_6Types() {
        dataTypesDict[HealthConstants.HEADACHE_UNSPECIFIED] = HKSampleType.categoryType(forIdentifier: .headache)!
        dataTypesDict[HealthConstants.HEADACHE_NOT_PRESENT] = HKSampleType.categoryType(forIdentifier: .headache)!
        dataTypesDict[HealthConstants.HEADACHE_MILD] = HKSampleType.categoryType(forIdentifier: .headache)!
        dataTypesDict[HealthConstants.HEADACHE_MODERATE] = HKSampleType.categoryType(forIdentifier: .headache)!
        dataTypesDict[HealthConstants.HEADACHE_SEVERE] = HKSampleType.categoryType(forIdentifier: .headache)!

        headacheType = Set([
            HKSampleType.categoryType(forIdentifier: .headache)!,
        ])
    }

    /// Initialize iOS 14 specific data types
    @available(iOS 14.0, *)
    private func initializeIOS14Types() {
        dataTypesDict[HealthConstants.ELECTROCARDIOGRAM] = HKSampleType.electrocardiogramType()
        dataTypesDict[HealthConstants.WALKING_SPEED] = HKSampleType.quantityType(forIdentifier: .walkingSpeed)

        unitDict[HealthConstants.VOLT] = HKUnit.volt()
        unitDict[HealthConstants.INCHES_OF_MERCURY] = HKUnit.inchesOfMercury()

        workoutActivityTypeMap["CARDIO_DANCE"] = HKWorkoutActivityType.cardioDance
        workoutActivityTypeMap["SOCIAL_DANCE"] = HKWorkoutActivityType.socialDance
        workoutActivityTypeMap["PICKLEBALL"] = HKWorkoutActivityType.pickleball
        workoutActivityTypeMap["COOLDOWN"] = HKWorkoutActivityType.cooldown

        if #available(iOS 14.5, *) {
            dataTypesDict[HealthConstants.APPLE_MOVE_TIME] = HKSampleType.quantityType(forIdentifier: .appleMoveTime)!
        }
    }

    /// Initialize iOS 16 specific data types
    @available(iOS 16.0, *)
    private func initializeIOS16Types() {
        dataTypesDict[HealthConstants.ATRIAL_FIBRILLATION_BURDEN] = HKQuantityType.quantityType(forIdentifier: .atrialFibrillationBurden)!
        dataTypesDict[HealthConstants.WATER_TEMPERATURE] = HKQuantityType.quantityType(forIdentifier: .waterTemperature)!
        dataTypesDict[HealthConstants.UNDERWATER_DEPTH] = HKQuantityType.quantityType(forIdentifier: .underwaterDepth)!
        dataTypesDict[HealthConstants.UV_INDEX] = HKQuantityType.quantityType(forIdentifier: .uvExposure)!
        dataTypesDict[HealthConstants.SLEEP_WRIST_TEMPERATURE] = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!

        dataQuantityTypesDict[HealthConstants.UV_INDEX] = HKQuantityType.quantityType(forIdentifier: .uvExposure)!
        dataQuantityTypesDict[HealthConstants.SLEEP_WRIST_TEMPERATURE] = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
    }
}
