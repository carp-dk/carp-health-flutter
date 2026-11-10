part of '../../health.dart';

/// List of all available health data types.
enum HealthDataType {
  ACTIVE_ENERGY_BURNED,
  ATRIAL_FIBRILLATION_BURDEN,
  APPLE_STAND_HOUR,
  APPLE_MOVE_TIME,
  APPLE_STAND_TIME,
  AUDIOGRAM,
  BASAL_ENERGY_BURNED,
  BLOOD_GLUCOSE,
  BLOOD_OXYGEN,
  BLOOD_PRESSURE_DIASTOLIC,
  BLOOD_PRESSURE_SYSTOLIC,
  BODY_FAT_PERCENTAGE,
  LEAN_BODY_MASS,
  BODY_MASS_INDEX,
  BODY_TEMPERATURE,
  BODY_WATER_MASS,
  DIETARY_CARBS_CONSUMED,
  DIETARY_CAFFEINE,
  DIETARY_ENERGY_CONSUMED,
  DIETARY_FATS_CONSUMED,
  DIETARY_PROTEIN_CONSUMED,
  DIETARY_FIBER,
  DIETARY_SUGAR,
  DIETARY_FAT_MONOUNSATURATED,
  DIETARY_FAT_POLYUNSATURATED,
  DIETARY_FAT_SATURATED,
  DIETARY_CHOLESTEROL,
  DIETARY_VITAMIN_A,
  DIETARY_THIAMIN,
  DIETARY_RIBOFLAVIN,
  DIETARY_NIACIN,
  DIETARY_PANTOTHENIC_ACID,
  DIETARY_VITAMIN_B6,
  DIETARY_BIOTIN,
  DIETARY_VITAMIN_B12,
  DIETARY_VITAMIN_C,
  DIETARY_VITAMIN_D,
  DIETARY_VITAMIN_E,
  DIETARY_VITAMIN_K,
  DIETARY_FOLATE,
  DIETARY_CALCIUM,
  DIETARY_CHLORIDE,
  DIETARY_IRON,
  DIETARY_MAGNESIUM,
  DIETARY_PHOSPHORUS,
  DIETARY_POTASSIUM,
  DIETARY_SODIUM,
  DIETARY_ZINC,
  DIETARY_CHROMIUM,
  DIETARY_COPPER,
  DIETARY_IODINE,
  DIETARY_MANGANESE,
  DIETARY_MOLYBDENUM,
  DIETARY_SELENIUM,
  FORCED_EXPIRATORY_VOLUME,
  HEART_RATE,
  HEART_RATE_VARIABILITY_SDNN,
  HEART_RATE_VARIABILITY_RMSSD,
  HEIGHT,
  INSULIN_DELIVERY,
  RESTING_HEART_RATE,
  RESPIRATORY_RATE,
  PERIPHERAL_PERFUSION_INDEX,
  STEPS,
  WAIST_CIRCUMFERENCE,
  WALKING_HEART_RATE,
  WEIGHT,
  DISTANCE_WALKING_RUNNING,
  DISTANCE_SWIMMING,
  DISTANCE_CYCLING,
  FLIGHTS_CLIMBED,
  DISTANCE_DELTA,
  WALKING_SPEED,
  SPEED,

  /// Power in watts, for example from a cycling power meter. Read only:
  /// writing it throws an [ArgumentError].
  ///
  ///  * iOS 17 and later: cycling power, HealthKit's
  ///    `HKQuantityTypeIdentifier.cyclingPower`.
  ///  * Android: the samples of Health Connect's `PowerRecord`, the power of
  ///    any exercise, for example cycling or rowing.
  POWER,

  /// Cycling cadence in revolutions per minute: how fast the pedals turn.
  /// Read only: writing it throws an [ArgumentError].
  ///
  ///  * iOS 17 and later: HealthKit's `HKQuantityTypeIdentifier.cyclingCadence`.
  ///  * Android: the samples of Health Connect's `CyclingPedalingCadenceRecord`.
  CYCLING_CADENCE,

  /// Maximal oxygen consumption (VO2 max) in milliliters per kilogram of body
  /// weight per minute.
  ///
  ///  * iOS: HealthKit's `HKQuantityTypeIdentifier.vo2Max`.
  ///  * Android: Health Connect's `Vo2MaxRecord`; declare the `READ_VO2_MAX`
  ///    and `WRITE_VO2_MAX` permissions. Health Connect takes values from 0 to
  ///    100: [Health.writeHealthData] returns false for others.
  ///
  /// [Health.getHealthIntervalDataFromTypes] returns the average of each
  /// interval on iOS and no data points on Android, where Health Connect has
  /// no VO2 max aggregate.
  VO2_MAX,

  // HealthKit quantity types, iOS only. On an iOS version before the one named,
  // reads of a type fail with HealthErrorCode.notSupported.
  /// HealthKit's `timeInDaylight`, iOS 17 and later.
  TIME_IN_DAYLIGHT,

  /// HealthKit's `walkingDoubleSupportPercentage`.
  WALKING_DOUBLE_SUPPORT_PERCENTAGE,

  /// HealthKit's `walkingStepLength`.
  WALKING_STEP_LENGTH,

  /// HealthKit's `walkingAsymmetryPercentage`. Read only: requesting write
  /// access throws an [ArgumentError].
  WALKING_ASYMMETRY_PERCENTAGE,

  /// HealthKit's `appleWalkingSteadiness`. Read only: requesting write access
  /// throws an [ArgumentError].
  APPLE_WALKING_STEADINESS,

  /// HealthKit's `stairAscentSpeed`.
  STAIR_ASCENT_SPEED,

  /// HealthKit's `stairDescentSpeed`.
  STAIR_DESCENT_SPEED,

  /// HealthKit's `sixMinuteWalkTestDistance`.
  SIX_MINUTE_WALK_TEST_DISTANCE,

  /// HealthKit's `runningPower`, iOS 16 and later.
  RUNNING_POWER,

  /// HealthKit's `runningSpeed`, iOS 16 and later.
  RUNNING_SPEED,

  /// HealthKit's `runningStrideLength`, iOS 16 and later.
  RUNNING_STRIDE_LENGTH,

  /// HealthKit's `runningVerticalOscillation`, iOS 16 and later.
  RUNNING_VERTICAL_OSCILLATION,

  /// HealthKit's `runningGroundContactTime`, iOS 16 and later.
  RUNNING_GROUND_CONTACT_TIME,

  /// HealthKit's `heartRateRecoveryOneMinute`, iOS 16 and later.
  HEART_RATE_RECOVERY_ONE_MINUTE,

  /// HealthKit's `physicalEffort`, iOS 17 and later.
  PHYSICAL_EFFORT,

  /// HealthKit's `environmentalAudioExposure`.
  ENVIRONMENTAL_AUDIO_EXPOSURE,

  /// HealthKit's `headphoneAudioExposure`.
  HEADPHONE_AUDIO_EXPOSURE,

  /// HealthKit's `numberOfTimesFallen`.
  NUMBER_OF_TIMES_FALLEN,

  /// HealthKit's `basalBodyTemperature`.
  BASAL_BODY_TEMPERATURE,

  /// HealthKit's `peakExpiratoryFlowRate`.
  PEAK_EXPIRATORY_FLOW,

  /// HealthKit's `forcedVitalCapacity`.
  FORCED_VITAL_CAPACITY,

  /// HealthKit's `inhalerUsage`.
  INHALER_USAGE,

  /// HealthKit's `bloodAlcoholContent`.
  BLOOD_ALCOHOL_CONTENT,

  /// HealthKit's `numberOfAlcoholicBeverages`.
  NUMBER_OF_ALCOHOLIC_BEVERAGES,

  /// HealthKit's `pushCount`.
  PUSH_COUNT,

  /// HealthKit's `swimmingStrokeCount`.
  SWIMMING_STROKE_COUNT,

  /// HealthKit's `distanceWheelchair`.
  DISTANCE_WHEELCHAIR,

  /// HealthKit's `distanceDownhillSnowSports`.
  DISTANCE_DOWNHILL_SNOW_SPORTS,

  /// HealthKit's `distanceCrossCountrySkiing`, iOS 18 and later.
  DISTANCE_CROSS_COUNTRY_SKIING,

  /// HealthKit's `distancePaddleSports`, iOS 18 and later.
  DISTANCE_PADDLE_SPORTS,

  /// HealthKit's `distanceRowing`, iOS 18 and later.
  DISTANCE_ROWING,

  /// HealthKit's `distanceSkatingSports`, iOS 18 and later.
  DISTANCE_SKATING_SPORTS,

  /// HealthKit's `cyclingSpeed`, iOS 17 and later.
  CYCLING_SPEED,

  /// HealthKit's `cyclingFunctionalThresholdPower`, iOS 17 and later.
  CYCLING_FUNCTIONAL_THRESHOLD_POWER,

  /// HealthKit's `crossCountrySkiingSpeed`, iOS 18 and later.
  CROSS_COUNTRY_SKIING_SPEED,

  /// HealthKit's `paddleSportsSpeed`, iOS 18 and later.
  PADDLE_SPORTS_SPEED,

  /// HealthKit's `rowingSpeed`, iOS 18 and later.
  ROWING_SPEED,

  /// HealthKit's `environmentalSoundReduction`, iOS 16 and later.
  ENVIRONMENTAL_SOUND_REDUCTION,

  /// HealthKit's `workoutEffortScore`, iOS 18 and later.
  WORKOUT_EFFORT_SCORE,

  /// HealthKit's `estimatedWorkoutEffortScore`, iOS 18 and later.
  ESTIMATED_WORKOUT_EFFORT_SCORE,

  /// HealthKit's `appleSleepingBreathingDisturbances`, iOS 18 and later.
  /// Read only: requesting write access throws an [ArgumentError].
  APPLE_SLEEPING_BREATHING_DISTURBANCES,

  /// Mindfulness sessions, such as meditation, in minutes: the value of a
  /// session is the minutes from its start to its end. Write a session with
  /// its type and title with [Health.writeMindfulnessSession].
  ///
  ///  * iOS: HealthKit's `HKCategoryTypeIdentifier.mindfulSession`.
  ///  * Android: Health Connect's `MindfulnessSessionRecord`, on devices whose
  ///    Health Connect has them ([Health.isMindfulnessSessionAvailable]).
  MINDFULNESS,

  WATER,
  SLEEP_ASLEEP,
  SLEEP_AWAKE_IN_BED,
  SLEEP_AWAKE,
  SLEEP_DEEP,
  SLEEP_IN_BED,
  SLEEP_LIGHT,
  SLEEP_OUT_OF_BED,
  SLEEP_REM,
  SLEEP_SESSION,

  /// Sleep of an unknown stage, in minutes.
  ///
  ///  * Android: the stages of Health Connect's sleep sessions whose stage is
  ///    unknown (`SleepSessionRecord.STAGE_TYPE_UNKNOWN`).
  ///  * iOS: sleep analysis samples with a value the plugin has no type for:
  ///    none in today's HealthKit, but values Apple adds later read as this
  ///    type instead of being left out. HealthKit's `asleepUnspecified` is
  ///    [HealthDataType.SLEEP_ASLEEP]. HealthKit has no unknown sleep value to
  ///    write: [Health.writeHealthData] throws a [HealthException] with
  ///    [HealthErrorCode.notSupported], and [Health.writeSleepSession] keeps
  ///    an unknown stage as time in bed.
  SLEEP_UNKNOWN,

  EXERCISE_TIME,
  WORKOUT,
  WORKOUT_ROUTE,
  HEADACHE_NOT_PRESENT,
  HEADACHE_MILD,
  HEADACHE_MODERATE,
  HEADACHE_SEVERE,
  HEADACHE_UNSPECIFIED,
  NUTRITION,
  UV_INDEX,
  // HealthKit Characteristics
  GENDER,
  BIRTH_DATE,
  BLOOD_TYPE,
  MENSTRUATION_FLOW,
  WATER_TEMPERATURE,
  UNDERWATER_DEPTH,
  SLEEP_WRIST_TEMPERATURE,

  // Heart Rate events (specific to Apple Watch)
  HIGH_HEART_RATE_EVENT,
  LOW_HEART_RATE_EVENT,
  IRREGULAR_HEART_RATE_EVENT,
  ELECTRODERMAL_ACTIVITY,
  ELECTROCARDIOGRAM,

  // Health Connect

  /// Energy burned, active and basal, in kilocalories: Health Connect's
  /// `TotalCaloriesBurnedRecord`. Android only, as HealthKit has no total: on
  /// iOS, read [ACTIVE_ENERGY_BURNED] and [BASAL_ENERGY_BURNED].
  TOTAL_CALORIES_BURNED,
  ACTIVITY_INTENSITY,
  SKIN_TEMPERATURE,
}
