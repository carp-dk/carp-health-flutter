/// Which [TypeCategory] each of the plugin's data types belongs to. Use it through
/// `HealthDataTypeInfo.category`.
library;

import 'package:health/health.dart';

import '../type_category.dart';

/// The category of [type], loosely following the Apple Health and Health Connect groupings. The
/// switch has no default case, so a type added to the plugin does not compile here until it has
/// a category.
TypeCategory typeCategory(HealthDataType type) => switch (type) {
  HealthDataType.ACTIVE_ENERGY_BURNED ||
  HealthDataType.BASAL_ENERGY_BURNED ||
  HealthDataType.TOTAL_CALORIES_BURNED ||
  HealthDataType.STEPS ||
  HealthDataType.FLIGHTS_CLIMBED ||
  HealthDataType.DISTANCE_DELTA ||
  HealthDataType.DISTANCE_WALKING_RUNNING ||
  HealthDataType.DISTANCE_CYCLING ||
  HealthDataType.DISTANCE_SWIMMING ||
  HealthDataType.DISTANCE_WHEELCHAIR ||
  HealthDataType.DISTANCE_DOWNHILL_SNOW_SPORTS ||
  HealthDataType.DISTANCE_CROSS_COUNTRY_SKIING ||
  HealthDataType.DISTANCE_PADDLE_SPORTS ||
  HealthDataType.DISTANCE_ROWING ||
  HealthDataType.DISTANCE_SKATING_SPORTS ||
  HealthDataType.PUSH_COUNT ||
  HealthDataType.SWIMMING_STROKE_COUNT ||
  HealthDataType.APPLE_STAND_HOUR ||
  HealthDataType.APPLE_STAND_TIME ||
  HealthDataType.APPLE_MOVE_TIME ||
  HealthDataType.EXERCISE_TIME ||
  HealthDataType.PHYSICAL_EFFORT ||
  HealthDataType.ACTIVITY_INTENSITY => TypeCategory.activity,

  HealthDataType.WEIGHT ||
  HealthDataType.HEIGHT ||
  HealthDataType.BODY_MASS_INDEX ||
  HealthDataType.BODY_FAT_PERCENTAGE ||
  HealthDataType.LEAN_BODY_MASS ||
  HealthDataType.BODY_WATER_MASS ||
  HealthDataType.WAIST_CIRCUMFERENCE ||
  HealthDataType.BODY_TEMPERATURE ||
  HealthDataType.SKIN_TEMPERATURE => TypeCategory.body,

  HealthDataType.HEART_RATE ||
  HealthDataType.RESTING_HEART_RATE ||
  HealthDataType.WALKING_HEART_RATE ||
  HealthDataType.HEART_RATE_VARIABILITY_SDNN ||
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD ||
  HealthDataType.HEART_RATE_RECOVERY_ONE_MINUTE ||
  HealthDataType.HIGH_HEART_RATE_EVENT ||
  HealthDataType.LOW_HEART_RATE_EVENT ||
  HealthDataType.IRREGULAR_HEART_RATE_EVENT ||
  HealthDataType.ATRIAL_FIBRILLATION_BURDEN ||
  HealthDataType.ELECTROCARDIOGRAM ||
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC ||
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC ||
  HealthDataType.BLOOD_OXYGEN ||
  HealthDataType.BLOOD_GLUCOSE ||
  HealthDataType.RESPIRATORY_RATE ||
  HealthDataType.PERIPHERAL_PERFUSION_INDEX ||
  HealthDataType.VO2_MAX ||
  HealthDataType.FORCED_EXPIRATORY_VOLUME ||
  HealthDataType.FORCED_VITAL_CAPACITY ||
  HealthDataType.PEAK_EXPIRATORY_FLOW ||
  HealthDataType.INHALER_USAGE => TypeCategory.vitals,

  HealthDataType.SLEEP_SESSION ||
  HealthDataType.SLEEP_IN_BED ||
  HealthDataType.SLEEP_ASLEEP ||
  HealthDataType.SLEEP_AWAKE ||
  HealthDataType.SLEEP_AWAKE_IN_BED ||
  HealthDataType.SLEEP_LIGHT ||
  HealthDataType.SLEEP_DEEP ||
  HealthDataType.SLEEP_REM ||
  HealthDataType.SLEEP_OUT_OF_BED ||
  HealthDataType.SLEEP_UNKNOWN ||
  HealthDataType.SLEEP_WRIST_TEMPERATURE ||
  HealthDataType.APPLE_SLEEPING_BREATHING_DISTURBANCES => TypeCategory.sleep,

  HealthDataType.NUTRITION ||
  HealthDataType.WATER ||
  HealthDataType.DIETARY_CARBS_CONSUMED ||
  HealthDataType.DIETARY_CAFFEINE ||
  HealthDataType.DIETARY_ENERGY_CONSUMED ||
  HealthDataType.DIETARY_FATS_CONSUMED ||
  HealthDataType.DIETARY_PROTEIN_CONSUMED ||
  HealthDataType.DIETARY_FIBER ||
  HealthDataType.DIETARY_SUGAR ||
  HealthDataType.DIETARY_FAT_MONOUNSATURATED ||
  HealthDataType.DIETARY_FAT_POLYUNSATURATED ||
  HealthDataType.DIETARY_FAT_SATURATED ||
  HealthDataType.DIETARY_CHOLESTEROL ||
  HealthDataType.DIETARY_VITAMIN_A ||
  HealthDataType.DIETARY_THIAMIN ||
  HealthDataType.DIETARY_RIBOFLAVIN ||
  HealthDataType.DIETARY_NIACIN ||
  HealthDataType.DIETARY_PANTOTHENIC_ACID ||
  HealthDataType.DIETARY_VITAMIN_B6 ||
  HealthDataType.DIETARY_BIOTIN ||
  HealthDataType.DIETARY_VITAMIN_B12 ||
  HealthDataType.DIETARY_VITAMIN_C ||
  HealthDataType.DIETARY_VITAMIN_D ||
  HealthDataType.DIETARY_VITAMIN_E ||
  HealthDataType.DIETARY_VITAMIN_K ||
  HealthDataType.DIETARY_FOLATE ||
  HealthDataType.DIETARY_CALCIUM ||
  HealthDataType.DIETARY_CHLORIDE ||
  HealthDataType.DIETARY_IRON ||
  HealthDataType.DIETARY_MAGNESIUM ||
  HealthDataType.DIETARY_PHOSPHORUS ||
  HealthDataType.DIETARY_POTASSIUM ||
  HealthDataType.DIETARY_SODIUM ||
  HealthDataType.DIETARY_ZINC ||
  HealthDataType.DIETARY_CHROMIUM ||
  HealthDataType.DIETARY_COPPER ||
  HealthDataType.DIETARY_IODINE ||
  HealthDataType.DIETARY_MANGANESE ||
  HealthDataType.DIETARY_MOLYBDENUM ||
  HealthDataType.DIETARY_SELENIUM => TypeCategory.nutrition,

  HealthDataType.MINDFULNESS => TypeCategory.mindfulness,

  HealthDataType.MENSTRUATION_FLOW ||
  HealthDataType.SEXUAL_ACTIVITY ||
  HealthDataType.BASAL_BODY_TEMPERATURE => TypeCategory.cycle,

  HealthDataType.WORKOUT ||
  HealthDataType.WORKOUT_ROUTE ||
  HealthDataType.WORKOUT_EFFORT_SCORE ||
  HealthDataType.ESTIMATED_WORKOUT_EFFORT_SCORE ||
  HealthDataType.POWER ||
  HealthDataType.CYCLING_CADENCE ||
  HealthDataType.CYCLING_SPEED ||
  HealthDataType.CYCLING_FUNCTIONAL_THRESHOLD_POWER ||
  HealthDataType.SPEED ||
  HealthDataType.RUNNING_POWER ||
  HealthDataType.RUNNING_SPEED ||
  HealthDataType.RUNNING_STRIDE_LENGTH ||
  HealthDataType.RUNNING_VERTICAL_OSCILLATION ||
  HealthDataType.RUNNING_GROUND_CONTACT_TIME ||
  HealthDataType.CROSS_COUNTRY_SKIING_SPEED ||
  HealthDataType.PADDLE_SPORTS_SPEED ||
  HealthDataType.ROWING_SPEED => TypeCategory.workouts,

  HealthDataType.WALKING_SPEED ||
  HealthDataType.WALKING_STEP_LENGTH ||
  HealthDataType.WALKING_DOUBLE_SUPPORT_PERCENTAGE ||
  HealthDataType.WALKING_ASYMMETRY_PERCENTAGE ||
  HealthDataType.APPLE_WALKING_STEADINESS ||
  HealthDataType.STAIR_ASCENT_SPEED ||
  HealthDataType.STAIR_DESCENT_SPEED ||
  HealthDataType.SIX_MINUTE_WALK_TEST_DISTANCE ||
  HealthDataType.NUMBER_OF_TIMES_FALLEN => TypeCategory.mobility,

  HealthDataType.AUDIOGRAM ||
  HealthDataType.ENVIRONMENTAL_AUDIO_EXPOSURE ||
  HealthDataType.HEADPHONE_AUDIO_EXPOSURE ||
  HealthDataType.ENVIRONMENTAL_SOUND_REDUCTION => TypeCategory.hearing,

  HealthDataType.UV_INDEX ||
  HealthDataType.TIME_IN_DAYLIGHT ||
  HealthDataType.WATER_TEMPERATURE ||
  HealthDataType.UNDERWATER_DEPTH => TypeCategory.environment,

  HealthDataType.HEADACHE_NOT_PRESENT ||
  HealthDataType.HEADACHE_MILD ||
  HealthDataType.HEADACHE_MODERATE ||
  HealthDataType.HEADACHE_SEVERE ||
  HealthDataType.HEADACHE_UNSPECIFIED => TypeCategory.symptoms,

  HealthDataType.GENDER || HealthDataType.BIRTH_DATE || HealthDataType.BLOOD_TYPE => TypeCategory.characteristics,

  HealthDataType.INSULIN_DELIVERY ||
  HealthDataType.BLOOD_ALCOHOL_CONTENT ||
  HealthDataType.NUMBER_OF_ALCOHOLIC_BEVERAGES ||
  HealthDataType.ELECTRODERMAL_ACTIVITY => TypeCategory.other,
};
