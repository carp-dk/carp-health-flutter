/// Short display text for the values the plugin reads: a number with its unit symbol, a duration
/// for the time-based types, and a one-line summary for workouts, meals, audiograms and the
/// other typed values.
library;

import 'package:health/health.dart';

import 'formatters.dart';
import 'value_summaries.dart';

/// The value of [point] with its unit, such as "72 bpm", "7 h 32 min" for a sleep stage, "97%"
/// for blood oxygen, or "Running · 30 min · 5.2 km · 320 kcal" for a workout.
String formatPointValue(HealthDataPoint point) => switch (point.value) {
  NumericHealthValue(:final numericValue) => formatNumericValue(
    numericValue,
    point.unit,
    type: point.type,
    platform: point.sourcePlatform,
  ),
  final value => summarizeValue(value, point),
};

/// A numeric [value] in [unit], such as "72 bpm".
///
/// Time units show as durations ("1 h 25 min"), metres from 1 km as kilometres and grams below
/// one gram as milligrams or micrograms (nutrients). [type] lets codes read as words (blood type,
/// stand hours, ...), and [platform] scales percentages: HealthKit reports them as fractions
/// (0.97 is 97%), Health Connect from 0 to 100.
String formatNumericValue(num value, HealthDataUnit unit, {HealthDataType? type, HealthPlatformType? platform}) {
  final coded = type == null ? null : describeCodedValue(type, value);
  if (coded != null) return coded;
  if (!value.isFinite) return formatNumber(value);
  return switch (unit) {
    HealthDataUnit.MINUTE => formatDuration(minutesToDuration(value)),
    HealthDataUnit.SECOND => formatDuration(minutesToDuration(value / 60)),
    HealthDataUnit.DAY => formatDuration(minutesToDuration(value * Duration.minutesPerDay)),
    HealthDataUnit.PERCENT =>
      '${formatNumber(platform == HealthPlatformType.appleHealth ? value * 100 : value, maxDecimals: 1)}%',
    HealthDataUnit.METER when value.abs() >= 1000 => '${formatNumber(value / 1000)} km',
    HealthDataUnit.GRAM when value != 0 && value.abs() < 0.001 => '${formatNumber(value * 1e6)} µg',
    HealthDataUnit.GRAM when value != 0 && value.abs() < 1 => '${formatNumber(value * 1000)} mg',
    _ => _withUnit(formatNumber(value), unit),
  };
}

/// The symbol of [unit], such as "bpm" or "kcal"; empty for counts, scores and unitless values.
String formatUnit(HealthDataUnit unit) => switch (unit) {
  HealthDataUnit.GRAM => 'g',
  HealthDataUnit.KILOGRAM => 'kg',
  HealthDataUnit.OUNCE => 'oz',
  HealthDataUnit.POUND => 'lb',
  HealthDataUnit.STONE => 'st',
  HealthDataUnit.METER => 'm',
  HealthDataUnit.CENTIMETER => 'cm',
  HealthDataUnit.INCH => 'in',
  HealthDataUnit.FOOT => 'ft',
  HealthDataUnit.YARD => 'yd',
  HealthDataUnit.MILE => 'mi',
  HealthDataUnit.LITER => 'L',
  HealthDataUnit.MILLILITER => 'mL',
  HealthDataUnit.FLUID_OUNCE_US => 'fl oz',
  HealthDataUnit.FLUID_OUNCE_IMPERIAL => 'fl oz (imp.)',
  HealthDataUnit.CUP_US => 'cups',
  HealthDataUnit.CUP_IMPERIAL => 'cups (imp.)',
  HealthDataUnit.PINT_US => 'pt',
  HealthDataUnit.PINT_IMPERIAL => 'pt (imp.)',
  HealthDataUnit.PASCAL => 'Pa',
  HealthDataUnit.MILLIMETER_OF_MERCURY => 'mmHg',
  HealthDataUnit.INCHES_OF_MERCURY => 'inHg',
  HealthDataUnit.CENTIMETER_OF_WATER => 'cmH₂O',
  HealthDataUnit.ATMOSPHERE => 'atm',
  HealthDataUnit.DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL => 'dBA',
  HealthDataUnit.SECOND => 's',
  HealthDataUnit.MILLISECOND => 'ms',
  HealthDataUnit.MINUTE => 'min',
  HealthDataUnit.HOUR => 'h',
  HealthDataUnit.DAY => 'd',
  HealthDataUnit.JOULE => 'J',
  HealthDataUnit.KILOCALORIE => 'kcal',
  HealthDataUnit.LARGE_CALORIE => 'Cal',
  HealthDataUnit.SMALL_CALORIE => 'cal',
  HealthDataUnit.DEGREE_CELSIUS => '°C',
  HealthDataUnit.DEGREE_FAHRENHEIT => '°F',
  HealthDataUnit.KELVIN => 'K',
  HealthDataUnit.DECIBEL_HEARING_LEVEL => 'dB HL',
  HealthDataUnit.HERTZ => 'Hz',
  HealthDataUnit.SIEMEN => 'S',
  HealthDataUnit.VOLT => 'V',
  HealthDataUnit.INTERNATIONAL_UNIT => 'IU',
  HealthDataUnit.PERCENT => '%',
  HealthDataUnit.BEATS_PER_MINUTE => 'bpm',
  HealthDataUnit.RESPIRATIONS_PER_MINUTE => 'breaths/min',
  HealthDataUnit.MILLIGRAM_PER_DECILITER => 'mg/dL',
  HealthDataUnit.MILLIMOLES_PER_LITER => 'mmol/L',
  HealthDataUnit.METER_PER_SECOND => 'm/s',
  HealthDataUnit.WATT => 'W',
  HealthDataUnit.REVOLUTION_PER_MINUTE => 'rpm',
  HealthDataUnit.MILLILITER_PER_KILOGRAM_PER_MINUTE => 'mL/kg/min',
  HealthDataUnit.LITER_PER_MINUTE => 'L/min',
  HealthDataUnit.KILOCALORIE_PER_HOUR_KILOGRAM => 'kcal/hr·kg',
  HealthDataUnit.COUNT ||
  HealthDataUnit.APPLE_EFFORT_SCORE ||
  HealthDataUnit.UNKNOWN_UNIT ||
  HealthDataUnit.NO_UNIT => '',
};

/// [number] followed by the symbol of [unit]; percentages without a space, as is usual.
String _withUnit(String number, HealthDataUnit unit) {
  final symbol = formatUnit(unit);
  if (symbol.isEmpty) return number;
  return unit == HealthDataUnit.PERCENT ? '$number$symbol' : '$number $symbol';
}
