/// What the health plugin does with each data type on each platform, so the example offers only
/// calls that work.
///
/// Some of these facts are private in the plugin (its iOS read-only set) or live in its native
/// code (which types have interval data), so they are repeated here from the plugin's source and
/// README. The tests in `test/core/health/` check them against the plugin where it exposes them.
library;

import 'package:health/health.dart';

/// Per-platform rules for data types: OS and feature requirements, read-only types, types with a
/// write method of their own, and types that `getHealthIntervalDataFromTypes` aggregates.
abstract final class TypeRules {
  /// The iOS version each HealthKit type needs; on an older iOS, reads of the type fail with
  /// `HealthErrorCode.notSupported`. Types not listed work on every iOS the plugin supports (15
  /// and later). From the plugin's `initializeIOS16Types`, `initializeIOS17Types` and
  /// `initializeIOS18Types` (and the README's table of data types).
  static const Map<HealthDataType, int> iosMinimumVersion = {
    HealthDataType.ATRIAL_FIBRILLATION_BURDEN: 16,
    HealthDataType.WATER_TEMPERATURE: 16,
    HealthDataType.UNDERWATER_DEPTH: 16,
    HealthDataType.UV_INDEX: 16,
    HealthDataType.SLEEP_WRIST_TEMPERATURE: 16,
    HealthDataType.RUNNING_POWER: 16,
    HealthDataType.RUNNING_SPEED: 16,
    HealthDataType.RUNNING_STRIDE_LENGTH: 16,
    HealthDataType.RUNNING_VERTICAL_OSCILLATION: 16,
    HealthDataType.RUNNING_GROUND_CONTACT_TIME: 16,
    HealthDataType.HEART_RATE_RECOVERY_ONE_MINUTE: 16,
    HealthDataType.ENVIRONMENTAL_SOUND_REDUCTION: 16,
    HealthDataType.POWER: 17,
    HealthDataType.CYCLING_CADENCE: 17,
    HealthDataType.TIME_IN_DAYLIGHT: 17,
    HealthDataType.PHYSICAL_EFFORT: 17,
    HealthDataType.CYCLING_SPEED: 17,
    HealthDataType.CYCLING_FUNCTIONAL_THRESHOLD_POWER: 17,
    HealthDataType.DISTANCE_CROSS_COUNTRY_SKIING: 18,
    HealthDataType.DISTANCE_PADDLE_SPORTS: 18,
    HealthDataType.DISTANCE_ROWING: 18,
    HealthDataType.DISTANCE_SKATING_SPORTS: 18,
    HealthDataType.CROSS_COUNTRY_SKIING_SPEED: 18,
    HealthDataType.PADDLE_SPORTS_SPEED: 18,
    HealthDataType.ROWING_SPEED: 18,
    HealthDataType.WORKOUT_EFFORT_SCORE: 18,
    HealthDataType.ESTIMATED_WORKOUT_EFFORT_SCORE: 18,
    HealthDataType.APPLE_SLEEPING_BREATHING_DISTURBANCES: 18,
  };

  /// The Android types that only newer Health Connect versions have (README, "Health Connect
  /// features"). Without the feature, the plugin throws `HealthErrorCode.notSupported` for them,
  /// which would fail a whole read of several types, so the example leaves them out. Each has its
  /// own check: `isSkinTemperatureAvailable`, `isMindfulnessSessionAvailable` and
  /// `isActivityIntensityAvailable`.
  static const Set<HealthDataType> androidFeatureTypes = {
    HealthDataType.SKIN_TEMPERATURE,
    HealthDataType.MINDFULNESS,
    HealthDataType.ACTIVITY_INTENSITY,
  };

  /// The types HealthKit lets apps only read: the plugin's private `_readOnlyTypesIOS`.
  /// `requestAuthorization` throws an `ArgumentError` for write access to them, where HealthKit
  /// would crash the app, and so does `writeHealthData` on iOS.
  static const Set<HealthDataType> iosReadOnly = {
    HealthDataType.ELECTROCARDIOGRAM,
    HealthDataType.HIGH_HEART_RATE_EVENT,
    HealthDataType.LOW_HEART_RATE_EVENT,
    HealthDataType.IRREGULAR_HEART_RATE_EVENT,
    HealthDataType.WALKING_HEART_RATE,
    HealthDataType.ATRIAL_FIBRILLATION_BURDEN,
    HealthDataType.APPLE_STAND_HOUR,
    HealthDataType.APPLE_MOVE_TIME,
    HealthDataType.APPLE_STAND_TIME,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.SLEEP_WRIST_TEMPERATURE,
    HealthDataType.WALKING_ASYMMETRY_PERCENTAGE,
    HealthDataType.APPLE_WALKING_STEADINESS,
    HealthDataType.APPLE_SLEEPING_BREATHING_DISTURBANCES,
  };

  /// HealthKit characteristics, one value each that the user sets in the Health app. Only read
  /// access can be requested: write access makes the plugin's native side throw.
  static const Set<HealthDataType> characteristics = {
    HealthDataType.GENDER,
    HealthDataType.BIRTH_DATE,
    HealthDataType.BLOOD_TYPE,
  };

  /// Types that no plugin method writes on either platform: `writeHealthData` throws an
  /// `ArgumentError` for them.
  static const Set<HealthDataType> neverWritten = {HealthDataType.POWER, HealthDataType.CYCLING_CADENCE};

  /// Types written with a method of their own, which `writeHealthData` rejects or (for
  /// menstruation flow on Android) writes only as a raw code. Values name the method.
  static const Map<HealthDataType, String> dedicatedWriteMethods = {
    HealthDataType.WORKOUT: 'writeWorkoutData',
    HealthDataType.WORKOUT_ROUTE: 'startWorkoutRoute',
    HealthDataType.NUTRITION: 'writeMeal',
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC: 'writeBloodPressure',
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC: 'writeBloodPressure',
    HealthDataType.AUDIOGRAM: 'writeAudiogram',
    HealthDataType.INSULIN_DELIVERY: 'writeInsulinDelivery',
    HealthDataType.MENSTRUATION_FLOW: 'writeMenstruationFlow',
    HealthDataType.ACTIVITY_INTENSITY: 'writeActivityIntensity',
  };

  /// The Android types `getHealthIntervalDataFromTypes` returns data for: the sleep types (from
  /// the plugin's `SleepIntervalReader`) and the types of its `mapToAggregateMetric`. Health
  /// Connect has no aggregate for any other type, which then returns no data points.
  static const Set<HealthDataType> androidIntervalTypes = {
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_UNKNOWN,
    HealthDataType.HEIGHT,
    HealthDataType.WEIGHT,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WATER,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.POWER,
    HealthDataType.CYCLING_CADENCE,
    HealthDataType.ACTIVITY_INTENSITY,
    HealthDataType.MINDFULNESS,
    HealthDataType.SKIN_TEMPERATURE,
  };

  /// The iOS types without interval data. iOS aggregates its quantity types (HealthKit
  /// statistics), the sleep types and mindfulness; these are the other types and the quantity
  /// types the plugin registers without statistics. They throw `HealthErrorCode.invalidArgument`.
  static const Set<HealthDataType> iosTypesWithoutIntervals = {
    HealthDataType.APPLE_MOVE_TIME,
    HealthDataType.APPLE_STAND_TIME,
    HealthDataType.ATRIAL_FIBRILLATION_BURDEN,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.INSULIN_DELIVERY,
    HealthDataType.PERIPHERAL_PERFUSION_INDEX,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.UNDERWATER_DEPTH,
    HealthDataType.WALKING_SPEED,
    HealthDataType.WATER_TEMPERATURE,
    HealthDataType.APPLE_STAND_HOUR,
    HealthDataType.AUDIOGRAM,
    HealthDataType.ELECTROCARDIOGRAM,
    HealthDataType.HIGH_HEART_RATE_EVENT,
    HealthDataType.LOW_HEART_RATE_EVENT,
    HealthDataType.IRREGULAR_HEART_RATE_EVENT,
    HealthDataType.WORKOUT,
    HealthDataType.WORKOUT_ROUTE,
    HealthDataType.HEADACHE_NOT_PRESENT,
    HealthDataType.HEADACHE_MILD,
    HealthDataType.HEADACHE_MODERATE,
    HealthDataType.HEADACHE_SEVERE,
    HealthDataType.HEADACHE_UNSPECIFIED,
    HealthDataType.NUTRITION,
    HealthDataType.MENSTRUATION_FLOW,
    HealthDataType.GENDER,
    HealthDataType.BIRTH_DATE,
    HealthDataType.BLOOD_TYPE,
  };

  /// The data types of [platform]: the plugin's `dataTypeKeysAndroid` or `dataTypeKeysIOS`.
  static List<HealthDataType> platformTypes(HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect => dataTypeKeysAndroid,
    HealthPlatformType.appleHealth => dataTypeKeysIOS,
  };

  /// Whether no plugin method writes [type] on [platform], so there is nothing of the app's own
  /// to delete either. iOS adds HealthKit's read-only types, the characteristics and
  /// `SLEEP_UNKNOWN` (HealthKit has no unknown sleep value to write); Android adds
  /// `BODY_MASS_INDEX`, which Health Connect computes from weight and height.
  static bool isReadOnly(HealthDataType type, HealthPlatformType platform) {
    if (neverWritten.contains(type)) return true;
    return switch (platform) {
      HealthPlatformType.appleHealth =>
        iosReadOnly.contains(type) || characteristics.contains(type) || type == HealthDataType.SLEEP_UNKNOWN,
      HealthPlatformType.googleHealthConnect => type == HealthDataType.BODY_MASS_INDEX,
    };
  }

  /// Whether `writeHealthData` (and `writeHealthDataUUID`) writes [type] on [platform]: it is
  /// not read-only and has no write method of its own.
  static bool writesWithWriteHealthData(HealthDataType type, HealthPlatformType platform) =>
      !isReadOnly(type, platform) && !dedicatedWriteMethods.containsKey(type);

  /// Whether `delete` can remove the app's own data of [type] on [platform]: any type the app
  /// can write, except an Android workout route, which is part of its workout.
  static bool isDeletable(HealthDataType type, HealthPlatformType platform) =>
      !isReadOnly(type, platform) &&
      !(platform == HealthPlatformType.googleHealthConnect && type == HealthDataType.WORKOUT_ROUTE);

  /// Whether `getHealthIntervalDataFromTypes` aggregates [type] on [platform].
  static bool hasIntervals(HealthDataType type, HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect => androidIntervalTypes.contains(type),
    HealthPlatformType.appleHealth => dataTypeKeysIOS.contains(type) && !iosTypesWithoutIntervals.contains(type),
  };
}
