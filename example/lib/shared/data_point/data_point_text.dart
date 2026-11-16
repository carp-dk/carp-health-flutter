/// The short texts that describe a data point: its headline value, when it was recorded, and what it
/// means that a lookup by UUID found nothing. The data point tiles, the data point sheet and Read's
/// lookup share them, so all of them say the same.
library;

import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/health/health_type_info.dart';

/// The headline of [point] for big type: its value with unit for numbers (`formatPointValue`), and for
/// the typed values the one figure or word that says the most, such as the activity of a workout.
String dataPointHeadline(HealthDataPoint point) => switch (point.value) {
  WorkoutHealthValue(:final workoutActivityType) => formatEnumName(workoutActivityType),
  NutritionHealthValue(:final calories?) => '${formatNumber(calories, maxDecimals: 0)} kcal',
  NutritionHealthValue(:final name) => name ?? 'Meal',
  AudiogramHealthValue(:final frequencies) => _count(frequencies.length, 'frequency', 'frequencies'),
  ElectrocardiogramHealthValue(:final averageHeartRate?) => '${formatNumber(averageHeartRate, maxDecimals: 0)} bpm',
  // An empty route falls through to the summary, which says when it only lacks the routes permission.
  WorkoutRouteHealthValue(:final locations) when locations.isNotEmpty => _count(locations.length, 'location'),
  InsulinDeliveryHealthValue(:final units) => '${formatNumber(units)} IU',
  ActivityIntensityHealthValue(:final intensityLevel) => formatEnumName(intensityLevel),
  _ => formatPointValue(point),
};

/// When [point] was recorded: its time range, such as "Today, 07:00 – 07:30", or only its start for an
/// instant or a record shorter than a minute, whose range would read "07:00 – 07:00".
String dataPointTime(HealthDataPoint point) => point.dateTo.difference(point.dateFrom) < const Duration(minutes: 1)
    ? formatDateTime(point.dateFrom)
    : formatTimeRange(point.dateFrom, point.dateTo);

/// What it means that `Health.getHealthDataByUUID` returned null for a [type] record (README, "Fetch
/// single health data by UUID" and "Reads without the read permission"): the record is gone, it has
/// no data of the type asked for (Android), or it is another app's and the read permission is missing.
String uuidNotFoundMessage(HealthDataType type) =>
    'getHealthDataByUUID returned null: no ${type.label} record has this UUID (any more), the record has no '
    '${type.label} data (Android), or another app wrote it and read access is missing.';

/// "1 location" or "3 locations" (or the given [plural]).
String _count(int count, String singular, [String? plural]) =>
    '${formatNumber(count)} ${count == 1 ? singular : plural ?? '${singular}s'}';
