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
