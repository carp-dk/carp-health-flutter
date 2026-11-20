/// What the measurement form needs to know about a data type before `writeHealthData` writes it: a
/// plausible value to start from, the units HealthKit converts it from, whether the plugin uses the value
/// at all and whether the platform needs the measurement to last.
library;

import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';

/// Per-type rules for `writeHealthData` and `writeHealthDataUUID`, from the plugin's documentation.
abstract final class MeasurementRules {
  /// How long a new measurement lasts by default: the old example's 20 minutes, which suits the types
  /// Health Connect stores with a duration as well as the instant ones.
  static const Duration defaultSpan = Duration(minutes: 20);

  /// The sample value of each common type, in its default unit (`dataTypeToUnit`); percentages from 0
  /// to 100 (see [sampleValue]). The old example's values where it wrote the type.
  static const Map<HealthDataType, double> _samples = {
    HealthDataType.HEIGHT: 1.925,
    HealthDataType.WEIGHT: 90,
    HealthDataType.LEAN_BODY_MASS: 22,
    HealthDataType.BODY_WATER_MASS: 40,
    HealthDataType.BODY_MASS_INDEX: 22.5,
    HealthDataType.BODY_FAT_PERCENTAGE: 20,
    HealthDataType.WAIST_CIRCUMFERENCE: 0.85,
    HealthDataType.BODY_TEMPERATURE: 37,
    HealthDataType.BASAL_BODY_TEMPERATURE: 36.5,
    HealthDataType.SKIN_TEMPERATURE: 33.6,
    HealthDataType.HEART_RATE: 72,
    HealthDataType.RESTING_HEART_RATE: 58,
    HealthDataType.HEART_RATE_RECOVERY_ONE_MINUTE: 25,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: 30,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 30,
    HealthDataType.RESPIRATORY_RATE: 14,
    HealthDataType.BLOOD_GLUCOSE: 105,
    HealthDataType.BLOOD_OXYGEN: 98,
    HealthDataType.PERIPHERAL_PERFUSION_INDEX: 5,
    HealthDataType.BLOOD_ALCOHOL_CONTENT: 0.02,
    HealthDataType.VO2_MAX: 42.5,
    HealthDataType.STEPS: 90,
    HealthDataType.FLIGHTS_CLIMBED: 3,
    HealthDataType.ACTIVE_ENERGY_BURNED: 200,
    HealthDataType.BASAL_ENERGY_BURNED: 1600,
    HealthDataType.TOTAL_CALORIES_BURNED: 2200,
    HealthDataType.DISTANCE_DELTA: 1000,
    HealthDataType.DISTANCE_SWIMMING: 400,
    HealthDataType.DISTANCE_CYCLING: 5000,
    HealthDataType.SPEED: 2,
    HealthDataType.WALKING_SPEED: 1.5,
    HealthDataType.WALKING_STEP_LENGTH: 0.7,
    HealthDataType.WALKING_DOUBLE_SUPPORT_PERCENTAGE: 28,
    HealthDataType.RUNNING_STRIDE_LENGTH: 1.2,
    HealthDataType.RUNNING_VERTICAL_OSCILLATION: 0.08,
    HealthDataType.RUNNING_GROUND_CONTACT_TIME: 250,
    HealthDataType.RUNNING_POWER: 250,
    HealthDataType.CYCLING_FUNCTIONAL_THRESHOLD_POWER: 200,
    HealthDataType.PHYSICAL_EFFORT: 4,
    HealthDataType.WORKOUT_EFFORT_SCORE: 5,
    HealthDataType.ESTIMATED_WORKOUT_EFFORT_SCORE: 5,
    HealthDataType.TIME_IN_DAYLIGHT: 30,
    HealthDataType.ENVIRONMENTAL_AUDIO_EXPOSURE: 70,
    HealthDataType.HEADPHONE_AUDIO_EXPOSURE: 75,
    HealthDataType.ENVIRONMENTAL_SOUND_REDUCTION: 20,
    HealthDataType.FORCED_EXPIRATORY_VOLUME: 3.5,
    HealthDataType.FORCED_VITAL_CAPACITY: 4.5,
    HealthDataType.PEAK_EXPIRATORY_FLOW: 450,
    HealthDataType.ELECTRODERMAL_ACTIVITY: 0.000005,
    HealthDataType.WATER: 1.8,
    HealthDataType.WATER_TEMPERATURE: 22,
    HealthDataType.UNDERWATER_DEPTH: 5,
    HealthDataType.UV_INDEX: 4.3,
    HealthDataType.DIETARY_ENERGY_CONSUMED: 250,
    HealthDataType.DIETARY_CARBS_CONSUMED: 30,
    HealthDataType.DIETARY_PROTEIN_CONSUMED: 15,
    HealthDataType.DIETARY_FATS_CONSUMED: 10,
    HealthDataType.DIETARY_CAFFEINE: 0.08,
  };

  /// Sample values by unit, for the types [_samples] does not list.
  static const Map<HealthDataUnit, double> _byUnit = {
    HealthDataUnit.METER: 1000,
    HealthDataUnit.METER_PER_SECOND: 3,
    HealthDataUnit.GRAM: 0.01,
    HealthDataUnit.COUNT: 1,
    HealthDataUnit.PERCENT: 50,
    HealthDataUnit.BEATS_PER_MINUTE: 72,
  };

  /// Groups of units of one kind: HealthKit converts a value from any unit of its type's kind, and
  /// throws a `PlatformException` with code `INVALID_ARGUMENT` for a unit of another kind.
  static const List<List<HealthDataUnit>> _kinds = [
    [HealthDataUnit.GRAM, HealthDataUnit.KILOGRAM, HealthDataUnit.OUNCE, HealthDataUnit.POUND, HealthDataUnit.STONE],
    [
      HealthDataUnit.METER,
      HealthDataUnit.CENTIMETER,
      HealthDataUnit.INCH,
      HealthDataUnit.FOOT,
      HealthDataUnit.YARD,
      HealthDataUnit.MILE,
    ],
    [
      HealthDataUnit.LITER,
      HealthDataUnit.MILLILITER,
      HealthDataUnit.FLUID_OUNCE_US,
      HealthDataUnit.FLUID_OUNCE_IMPERIAL,
      HealthDataUnit.CUP_US,
      HealthDataUnit.CUP_IMPERIAL,
      HealthDataUnit.PINT_US,
      HealthDataUnit.PINT_IMPERIAL,
    ],
    [HealthDataUnit.MILLISECOND, HealthDataUnit.SECOND, HealthDataUnit.MINUTE, HealthDataUnit.HOUR, HealthDataUnit.DAY],
    [HealthDataUnit.KILOCALORIE, HealthDataUnit.LARGE_CALORIE, HealthDataUnit.SMALL_CALORIE, HealthDataUnit.JOULE],
    [HealthDataUnit.DEGREE_CELSIUS, HealthDataUnit.DEGREE_FAHRENHEIT, HealthDataUnit.KELVIN],
    [HealthDataUnit.MILLIGRAM_PER_DECILITER, HealthDataUnit.MILLIMOLES_PER_LITER],
  ];

  /// The types Health Connect stores with a duration: `writeHealthData` throws a `PlatformException`
  /// with code `INVALID_ARGUMENT` on Android when one ends when it starts.
  static const Set<HealthDataType> _healthConnectDurationTypes = {
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WATER,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.SKIN_TEMPERATURE,
    HealthDataType.MINDFULNESS,
  };

  /// The types HealthKit needs to last at least a millisecond.
  static const Set<HealthDataType> _healthKitDurationTypes = {
    HealthDataType.ENVIRONMENTAL_AUDIO_EXPOSURE,
    HealthDataType.HEADPHONE_AUDIO_EXPOSURE,
  };

  /// A plausible value of [type] in its default unit on [platform], for the form to start from.
  ///
  /// HealthKit's percent unit is a fraction (0.98 is 98 %) and Health Connect's goes from 0 to 100, and
  /// `writeHealthData` passes the value on as it is, so a percentage is divided by 100 on iOS.
  static double sampleValue(HealthDataType type, HealthPlatformType platform) {
    final unit = type.defaultUnit;
    final value = _samples[type] ?? _byUnit[unit] ?? 1;
    return unit == HealthDataUnit.PERCENT && platform == HealthPlatformType.appleHealth ? value / 100 : value;
  }

  /// The units [type] can be written in on iOS: the units of the kind of its default unit, which comes
  /// first. Android ignores the unit: Health Connect stores each type in a unit of its own.
  static List<HealthDataUnit> unitsFor(HealthDataType type) {
    final unit = type.defaultUnit;
    final kind = _kinds.where((units) => units.contains(unit)).firstOrNull ?? const [];
    return [unit, ...kind.where((other) => other != unit)];
  }

  /// Whether the plugin ignores the value of [type]: sleep and headache values are set from the type,
  /// and a mindfulness session is the time from its start to its end.
  static bool ignoresValue(HealthDataType type) =>
      type == HealthDataType.MINDFULNESS || type.name.startsWith('SLEEP_') || type.name.startsWith('HEADACHE_');

  /// Whether [platform] needs a measurement of [type] to end after it starts. The plugin then throws a
  /// `PlatformException` with code `INVALID_ARGUMENT` for one that ends when it starts.
  static bool needsDuration(HealthDataType type, HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect =>
      _healthConnectDurationTypes.contains(type) || type.name.startsWith('SLEEP_'),
    HealthPlatformType.appleHealth => _healthKitDurationTypes.contains(type),
  };

  /// Whether a value in [unit] is a fraction on [platform]: HealthKit's percent unit is (0.98 is 98 %).
  static bool isFraction(HealthDataUnit unit, HealthPlatformType platform) =>
      platform == HealthPlatformType.appleHealth && unit == HealthDataUnit.PERCENT;
}
