/// One-line summaries of the plugin's typed values (workouts, meals, audiograms, ECGs, ...) and
/// of the numeric values that are codes rather than amounts. `formatPointValue` uses them;
/// `NumericHealthValue` amounts are formatted by `formatNumericValue`.
library;

import 'package:health/health.dart';

import 'formatters.dart';

/// A one-line summary of a typed [value] of [point], such as "Running · 30 min · 5.2 km" for a
/// `WorkoutHealthValue`. Other values, `NumericHealthValue` included, show their `toString`.
String summarizeValue(HealthValue value, HealthDataPoint point) => switch (value) {
  WorkoutHealthValue() => _workout(value, point),
  NutritionHealthValue() => _nutrition(value),
  AudiogramHealthValue(:final frequencies) =>
    frequencies.isEmpty
        ? 'No frequencies'
        : '${_count(frequencies.length, 'frequency', 'frequencies')} · '
              '${formatNumber(_min(frequencies))}–${formatNumber(_max(frequencies))} Hz',
  ElectrocardiogramHealthValue(:final classification, :final averageHeartRate) => [
    classification == null || classification == ElectrocardiogramClassification.NOT_SET
        ? 'Not classified'
        : formatEnumName(classification),
    if (averageHeartRate != null) '${formatNumber(averageHeartRate, maxDecimals: 0)} bpm',
  ].join(' · '),
  InsulinDeliveryHealthValue(:final units, :final reason) => '${formatNumber(units)} IU · ${formatEnumName(reason)}',
  MenstruationFlowHealthValue(:final flow, :final isStartOfCycle) =>
    _flow(flow) + (isStartOfCycle == true ? ' · cycle start' : ''),
  ActivityIntensityHealthValue(:final intensityLevel, :final minutes) =>
    '${formatEnumName(intensityLevel)} · ${formatDuration(minutesToDuration(minutes))}',
  SkinTemperatureHealthValue(:final temperature, :final temperatureDelta) =>
    temperature == null
        ? 'Δ ${_signed(temperatureDelta)} °C'
        : '${formatNumber(temperature)} °C (Δ ${_signed(temperatureDelta)})',
  WorkoutRouteHealthValue(:final locations) =>
    // Without the Exercise routes permission, Health Connect reads another app's route without
    // its locations and marks it as needing consent (README, "Writing workout routes").
    locations.isEmpty && point.metadata?['route_requires_consent'] == true
        ? 'Route needs consent'
        : _count(locations.length, 'location'),
  _ => value.toString(),
};

/// The meaning of a numeric [value] of [type] that is a code rather than an amount, or null for
/// an amount: HealthKit characteristics, stand hours, heart rate events and effort scores.
String? describeCodedValue(HealthDataType type, num value) {
  if (!value.isFinite) return null;
  // Codes arrive as doubles over the method channel: compare them as ints.
  final code = value == value.truncate() ? value.toInt() : null;
  return switch (type) {
    // HealthKit's characteristics read as raw values, 0 when the user has not set them.
    HealthDataType.BIRTH_DATE =>
      code == 0 ? 'Not set' : formatDate(DateTime.fromMillisecondsSinceEpoch((value * 1000).round()), withYear: true),
    HealthDataType.GENDER => const {1: 'Female', 2: 'Male', 3: 'Other'}[code] ?? 'Not set',
    HealthDataType.BLOOD_TYPE =>
      const {1: 'A+', 2: 'A−', 3: 'B+', 4: 'B−', 5: 'AB+', 6: 'AB−', 7: 'O+', 8: 'O−'}[code] ?? 'Not set',
    // HKCategoryValueAppleStandHour: 0 is stood, 1 idle.
    HealthDataType.APPLE_STAND_HOUR => const {0: 'Stood', 1: 'Idle'}[code] ?? formatNumber(value),
    // Apple Watch events have no value of their own: the sample marks the event's time.
    HealthDataType.HIGH_HEART_RATE_EVENT ||
    HealthDataType.LOW_HEART_RATE_EVENT ||
    HealthDataType.IRREGULAR_HEART_RATE_EVENT => 'Detected',
    HealthDataType.WORKOUT_EFFORT_SCORE ||
    HealthDataType.ESTIMATED_WORKOUT_EFFORT_SCORE => '${formatNumber(value, maxDecimals: 1)} / 10',
    _ => null,
  };
}

/// [minutes] as a [Duration], to the microsecond.
Duration minutesToDuration(num minutes) => Duration(microseconds: (minutes * Duration.microsecondsPerMinute).round());

/// A workout: its type, length and totals, such as "Running · 30 min · 5.2 km · 320 kcal".
String _workout(WorkoutHealthValue workout, HealthDataPoint point) => [
  formatEnumName(workout.workoutActivityType),
  formatDuration(point.dateTo.difference(point.dateFrom)),
  if (workout.totalDistance != null) _distance(workout.totalDistance!),
  if (workout.totalEnergyBurned != null) '${formatNumber(workout.totalEnergyBurned!)} kcal',
  if (workout.totalSteps != null) _count(workout.totalSteps!, 'step'),
  if (workout.swimming?.laps.isNotEmpty ?? false) _count(workout.swimming!.laps.length, 'lap'),
].join(' · ');

/// A meal: its name or meal type, and its energy or macronutrients.
String _nutrition(NutritionHealthValue meal) {
  final mealType = meal.mealType == null || meal.mealType!.toUpperCase() == 'UNKNOWN' ? null : humanize(meal.mealType!);
  final macros = [
    if (meal.protein != null) 'P ${formatNumber(meal.protein!, maxDecimals: 1)} g',
    if (meal.carbs != null) 'C ${formatNumber(meal.carbs!, maxDecimals: 1)} g',
    if (meal.fat != null) 'F ${formatNumber(meal.fat!, maxDecimals: 1)} g',
  ];
  return [
    meal.name ?? mealType ?? 'Meal',
    if (meal.name != null && mealType != null) mealType,
    if (meal.calories != null) '${formatNumber(meal.calories!, maxDecimals: 0)} kcal' else ...macros,
  ].join(' · ');
}

/// A menstrual flow in words.
String _flow(MenstrualFlow? flow) => switch (flow) {
  null => 'Flow recorded',
  MenstrualFlow.none => 'No flow',
  MenstrualFlow.spotting => 'Spotting',
  MenstrualFlow.unspecified => 'Unspecified flow',
  _ => '${formatEnumName(flow)} flow',
};

/// [meters] in m, or in km from 1 km on.
String _distance(num meters) =>
    meters.abs() >= 1000 ? '${formatNumber(meters / 1000)} km' : '${formatNumber(meters, maxDecimals: 0)} m';

/// [value] with an explicit sign, such as "+0.4".
String _signed(num value) => value >= 0 ? '+${formatNumber(value)}' : formatNumber(value);

/// "1 lap" or "3 laps" (or the given [plural]).
String _count(int count, String singular, [String? plural]) =>
    '${formatNumber(count)} ${count == 1 ? singular : plural ?? '${singular}s'}';

num _min(List<num> values) => values.reduce((a, b) => a < b ? a : b);

num _max(List<num> values) => values.reduce((a, b) => a > b ? a : b);
