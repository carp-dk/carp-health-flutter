/// Material icons for the plugin's data types. Use them through `HealthDataTypeInfo.icon`.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'type_categories.dart';

/// The icon of [type]: a specific one where Material Icons has a fitting symbol, otherwise the
/// icon of the type's category (for example the nutrients share the nutrition icon).
IconData typeIcon(HealthDataType type) => switch (type) {
  // Activity
  HealthDataType.STEPS || HealthDataType.WALKING_SPEED => Icons.directions_walk,
  HealthDataType.ACTIVE_ENERGY_BURNED => Icons.local_fire_department,
  HealthDataType.TOTAL_CALORIES_BURNED => Icons.whatshot,
  HealthDataType.BASAL_ENERGY_BURNED => Icons.battery_charging_full,
  HealthDataType.FLIGHTS_CLIMBED ||
  HealthDataType.STAIR_ASCENT_SPEED ||
  HealthDataType.STAIR_DESCENT_SPEED => Icons.stairs,
  HealthDataType.DISTANCE_DELTA ||
  HealthDataType.DISTANCE_WALKING_RUNNING ||
  HealthDataType.WALKING_STEP_LENGTH ||
  HealthDataType.RUNNING_STRIDE_LENGTH ||
  HealthDataType.WAIST_CIRCUMFERENCE => Icons.straighten,
  HealthDataType.DISTANCE_CYCLING ||
  HealthDataType.CYCLING_SPEED ||
  HealthDataType.CYCLING_FUNCTIONAL_THRESHOLD_POWER => Icons.directions_bike,
  HealthDataType.DISTANCE_SWIMMING || HealthDataType.SWIMMING_STROKE_COUNT => Icons.pool,
  HealthDataType.DISTANCE_WHEELCHAIR || HealthDataType.PUSH_COUNT => Icons.accessible,
  HealthDataType.DISTANCE_DOWNHILL_SNOW_SPORTS => Icons.downhill_skiing,
  HealthDataType.DISTANCE_CROSS_COUNTRY_SKIING || HealthDataType.CROSS_COUNTRY_SKIING_SPEED => Icons.nordic_walking,
  HealthDataType.DISTANCE_PADDLE_SPORTS || HealthDataType.PADDLE_SPORTS_SPEED => Icons.kayaking,
  HealthDataType.DISTANCE_ROWING || HealthDataType.ROWING_SPEED => Icons.rowing,
  HealthDataType.DISTANCE_SKATING_SPORTS => Icons.ice_skating,
  HealthDataType.APPLE_STAND_HOUR || HealthDataType.APPLE_STAND_TIME => Icons.accessibility,
  HealthDataType.APPLE_MOVE_TIME ||
  HealthDataType.EXERCISE_TIME ||
  HealthDataType.SIX_MINUTE_WALK_TEST_DISTANCE ||
  HealthDataType.RUNNING_GROUND_CONTACT_TIME => Icons.timer,
  HealthDataType.PHYSICAL_EFFORT || HealthDataType.ACTIVITY_INTENSITY || HealthDataType.SPEED => Icons.speed,
  // Body
  HealthDataType.WEIGHT || HealthDataType.LEAN_BODY_MASS => Icons.monitor_weight,
  HealthDataType.HEIGHT || HealthDataType.RUNNING_VERTICAL_OSCILLATION => Icons.height,
  HealthDataType.BODY_FAT_PERCENTAGE => Icons.donut_large,
  HealthDataType.BODY_WATER_MASS => Icons.opacity,
  HealthDataType.BODY_TEMPERATURE ||
  HealthDataType.SKIN_TEMPERATURE ||
  HealthDataType.BASAL_BODY_TEMPERATURE ||
  HealthDataType.SLEEP_WRIST_TEMPERATURE => Icons.thermostat,
  // Heart and vitals
  HealthDataType.HEART_RATE || HealthDataType.RESTING_HEART_RATE || HealthDataType.WALKING_HEART_RATE => Icons.favorite,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN || HealthDataType.HEART_RATE_VARIABILITY_RMSSD => Icons.show_chart,
  HealthDataType.HEART_RATE_RECOVERY_ONE_MINUTE => Icons.trending_down,
  HealthDataType.HIGH_HEART_RATE_EVENT ||
  HealthDataType.LOW_HEART_RATE_EVENT ||
  HealthDataType.IRREGULAR_HEART_RATE_EVENT => Icons.warning_amber,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC || HealthDataType.BLOOD_PRESSURE_DIASTOLIC => Icons.compress,
  HealthDataType.BLOOD_OXYGEN => Icons.bubble_chart,
  HealthDataType.BLOOD_GLUCOSE => Icons.colorize,
  HealthDataType.PERIPHERAL_PERFUSION_INDEX => Icons.touch_app,
  HealthDataType.VO2_MAX => Icons.trending_up,
  HealthDataType.RESPIRATORY_RATE ||
  HealthDataType.FORCED_EXPIRATORY_VOLUME ||
  HealthDataType.FORCED_VITAL_CAPACITY ||
  HealthDataType.PEAK_EXPIRATORY_FLOW ||
  HealthDataType.APPLE_SLEEPING_BREATHING_DISTURBANCES => Icons.air,
  HealthDataType.INHALER_USAGE => Icons.medication,
  // Sleep
  HealthDataType.SLEEP_IN_BED => Icons.bed,
  HealthDataType.SLEEP_ASLEEP => Icons.nights_stay,
  HealthDataType.SLEEP_DEEP => Icons.dark_mode,
  HealthDataType.SLEEP_LIGHT => Icons.nightlight,
  HealthDataType.SLEEP_REM => Icons.remove_red_eye,
  HealthDataType.SLEEP_AWAKE || HealthDataType.SLEEP_AWAKE_IN_BED => Icons.wb_twilight,
  HealthDataType.SLEEP_OUT_OF_BED => Icons.directions_walk,
  HealthDataType.SLEEP_UNKNOWN => Icons.help_outline,
  // Nutrition
  HealthDataType.WATER => Icons.local_drink,
  HealthDataType.DIETARY_CAFFEINE => Icons.coffee,
  HealthDataType.DIETARY_ENERGY_CONSUMED => Icons.lunch_dining,
  HealthDataType.DIETARY_PROTEIN_CONSUMED => Icons.egg,
  HealthDataType.DIETARY_CARBS_CONSUMED => Icons.bakery_dining,
  HealthDataType.DIETARY_SUGAR => Icons.cake,
  HealthDataType.DIETARY_FIBER => Icons.grass,
  HealthDataType.DIETARY_FATS_CONSUMED ||
  HealthDataType.DIETARY_FAT_MONOUNSATURATED ||
  HealthDataType.DIETARY_FAT_POLYUNSATURATED ||
  HealthDataType.DIETARY_FAT_SATURATED ||
  HealthDataType.DIETARY_CHOLESTEROL => Icons.fastfood,
  // Workouts
  HealthDataType.WORKOUT_ROUTE => Icons.route,
  HealthDataType.WORKOUT_EFFORT_SCORE || HealthDataType.ESTIMATED_WORKOUT_EFFORT_SCORE => Icons.sports_score,
  HealthDataType.POWER || HealthDataType.RUNNING_POWER => Icons.bolt,
  HealthDataType.CYCLING_CADENCE => Icons.autorenew,
  HealthDataType.RUNNING_SPEED => Icons.directions_run,
  // Mobility
  HealthDataType.WALKING_DOUBLE_SUPPORT_PERCENTAGE => Icons.compare_arrows,
  HealthDataType.WALKING_ASYMMETRY_PERCENTAGE || HealthDataType.APPLE_WALKING_STEADINESS => Icons.balance,
  HealthDataType.NUMBER_OF_TIMES_FALLEN => Icons.personal_injury,
  // Hearing and environment
  HealthDataType.ENVIRONMENTAL_AUDIO_EXPOSURE => Icons.volume_up,
  HealthDataType.HEADPHONE_AUDIO_EXPOSURE => Icons.headphones,
  HealthDataType.ENVIRONMENTAL_SOUND_REDUCTION => Icons.noise_aware,
  HealthDataType.TIME_IN_DAYLIGHT => Icons.light_mode,
  HealthDataType.WATER_TEMPERATURE => Icons.waves,
  HealthDataType.UNDERWATER_DEPTH => Icons.scuba_diving,
  // Symptoms: a face for each headache severity
  HealthDataType.HEADACHE_NOT_PRESENT => Icons.sentiment_satisfied,
  HealthDataType.HEADACHE_MILD => Icons.sentiment_neutral,
  HealthDataType.HEADACHE_MODERATE => Icons.sentiment_dissatisfied,
  HealthDataType.HEADACHE_SEVERE => Icons.sentiment_very_dissatisfied,
  // Characteristics and other
  HealthDataType.GENDER => Icons.wc,
  HealthDataType.BIRTH_DATE => Icons.cake_outlined,
  HealthDataType.BLOOD_TYPE => Icons.bloodtype,
  HealthDataType.INSULIN_DELIVERY => Icons.vaccines,
  HealthDataType.BLOOD_ALCOHOL_CONTENT || HealthDataType.NUMBER_OF_ALCOHOLIC_BEVERAGES => Icons.wine_bar,
  HealthDataType.ELECTRODERMAL_ACTIVITY => Icons.electric_bolt,
  _ => typeCategory(type).icon,
};
