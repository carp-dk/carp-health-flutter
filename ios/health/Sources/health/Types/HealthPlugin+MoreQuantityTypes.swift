import HealthKit

/// More HealthKit quantity types, by the iOS version that has them. Each is registered as a sample
/// type and as a quantity type, so that it has interval data too: sums for cumulative types,
/// averages for the others.
extension HealthPlugin {
    /// Initialize the types every supported iOS version has (the plugin needs iOS 15)
    func initializeMoreQuantityTypes() {
        registerQuantityTypes([
            HealthConstants.WALKING_DOUBLE_SUPPORT_PERCENTAGE: .walkingDoubleSupportPercentage,
            HealthConstants.WALKING_STEP_LENGTH: .walkingStepLength,
            HealthConstants.WALKING_ASYMMETRY_PERCENTAGE: .walkingAsymmetryPercentage,
            HealthConstants.APPLE_WALKING_STEADINESS: .appleWalkingSteadiness,
            HealthConstants.STAIR_ASCENT_SPEED: .stairAscentSpeed,
            HealthConstants.STAIR_DESCENT_SPEED: .stairDescentSpeed,
            HealthConstants.SIX_MINUTE_WALK_TEST_DISTANCE: .sixMinuteWalkTestDistance,
            HealthConstants.ENVIRONMENTAL_AUDIO_EXPOSURE: .environmentalAudioExposure,
            HealthConstants.HEADPHONE_AUDIO_EXPOSURE: .headphoneAudioExposure,
            HealthConstants.NUMBER_OF_TIMES_FALLEN: .numberOfTimesFallen,
            HealthConstants.BASAL_BODY_TEMPERATURE: .basalBodyTemperature,
            HealthConstants.PEAK_EXPIRATORY_FLOW: .peakExpiratoryFlowRate,
            HealthConstants.FORCED_VITAL_CAPACITY: .forcedVitalCapacity,
            HealthConstants.INHALER_USAGE: .inhalerUsage,
            HealthConstants.BLOOD_ALCOHOL_CONTENT: .bloodAlcoholContent,
            HealthConstants.NUMBER_OF_ALCOHOLIC_BEVERAGES: .numberOfAlcoholicBeverages,
            HealthConstants.PUSH_COUNT: .pushCount,
            HealthConstants.SWIMMING_STROKE_COUNT: .swimmingStrokeCount,
            HealthConstants.DISTANCE_WHEELCHAIR: .distanceWheelchair,
            HealthConstants.DISTANCE_DOWNHILL_SNOW_SPORTS: .distanceDownhillSnowSports,
        ])
    }

    /// Initialize more iOS 16 specific data types
    @available(iOS 16.0, *)
    func initializeMoreIOS16QuantityTypes() {
        registerQuantityTypes([
            HealthConstants.RUNNING_POWER: .runningPower,
            HealthConstants.RUNNING_SPEED: .runningSpeed,
            HealthConstants.RUNNING_STRIDE_LENGTH: .runningStrideLength,
            HealthConstants.RUNNING_VERTICAL_OSCILLATION: .runningVerticalOscillation,
            HealthConstants.RUNNING_GROUND_CONTACT_TIME: .runningGroundContactTime,
            HealthConstants.HEART_RATE_RECOVERY_ONE_MINUTE: .heartRateRecoveryOneMinute,
            HealthConstants.ENVIRONMENTAL_SOUND_REDUCTION: .environmentalSoundReduction,
        ])
    }

    /// Initialize more iOS 17 specific data types
    @available(iOS 17.0, *)
    func initializeMoreIOS17QuantityTypes() {
        registerQuantityTypes([
            HealthConstants.TIME_IN_DAYLIGHT: .timeInDaylight,
            HealthConstants.PHYSICAL_EFFORT: .physicalEffort,
            HealthConstants.CYCLING_SPEED: .cyclingSpeed,
            HealthConstants.CYCLING_FUNCTIONAL_THRESHOLD_POWER: .cyclingFunctionalThresholdPower,
        ])
    }

    /// Initialize iOS 18 specific data types
    @available(iOS 18.0, *)
    func initializeIOS18Types() {
        unitDict[HealthConstants.APPLE_EFFORT_SCORE] = HKUnit.appleEffortScore()

        registerQuantityTypes([
            HealthConstants.DISTANCE_CROSS_COUNTRY_SKIING: .distanceCrossCountrySkiing,
            HealthConstants.DISTANCE_PADDLE_SPORTS: .distancePaddleSports,
            HealthConstants.DISTANCE_ROWING: .distanceRowing,
            HealthConstants.DISTANCE_SKATING_SPORTS: .distanceSkatingSports,
            HealthConstants.CROSS_COUNTRY_SKIING_SPEED: .crossCountrySkiingSpeed,
            HealthConstants.PADDLE_SPORTS_SPEED: .paddleSportsSpeed,
            HealthConstants.ROWING_SPEED: .rowingSpeed,
            HealthConstants.WORKOUT_EFFORT_SCORE: .workoutEffortScore,
            HealthConstants.ESTIMATED_WORKOUT_EFFORT_SCORE: .estimatedWorkoutEffortScore,
            HealthConstants.APPLE_SLEEPING_BREATHING_DISTURBANCES: .appleSleepingBreathingDisturbances,
        ])
    }

    /// Registers the quantity type of each identifier under its key in dataTypesDict and
    /// dataQuantityTypesDict.
    private func registerQuantityTypes(_ identifiers: [String: HKQuantityTypeIdentifier]) {
        for (key, identifier) in identifiers {
            let quantityType = HKQuantityType.quantityType(forIdentifier: identifier)!
            dataTypesDict[key] = quantityType
            dataQuantityTypesDict[key] = quantityType
        }
    }
}
