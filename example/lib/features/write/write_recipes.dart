/// The registry of the Write feature: one [WriteRecipe] for every write method of the plugin, in the
/// order the Write page shows them.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import 'forms/activity_intensity_form.dart';
import 'forms/audiogram_form.dart';
import 'forms/blood_oxygen_form.dart';
import 'forms/blood_pressure_form.dart';
import 'forms/insulin_delivery_form.dart';
import 'forms/meal_form.dart';
import 'forms/measurement_form.dart';
import 'forms/menstruation_flow_form.dart';
import 'forms/mindfulness_form.dart';
import 'forms/sleep_session_form.dart';
import 'forms/workout_form.dart';
import 'forms/workout_route_form.dart';
import 'write_recipe.dart';

/// Every write recipe of the example. Each recipe takes its shape and colours from the category of
/// the data it writes, so it looks like that data in the rest of the app.
abstract final class WriteRecipes {
  /// The recipes, in catalogue order: the general measurement first, then the methods for typed data.
  static final List<WriteRecipe> all = List.unmodifiable(<WriteRecipe>[
    WriteRecipe(
      id: WriteRecipeId.measurement,
      title: 'Measurement',
      summary: 'One value of any writable type',
      description:
          'Writes one value of a data type, such as a heart rate or a weight. writeHealthData returns '
          'whether it was saved; writeHealthDataUUID returns the new record\'s UUID (an empty string when '
          'nothing was saved), to read it back with getHealthDataByUUID or delete it with deleteByUUID. '
          'The unit is iOS only, as Health Connect stores each type in a unit of its own, and types that '
          'Health Connect stores with a duration, such as steps, need an end after the start.',
      methods: const ['writeHealthData', 'writeHealthDataUUID'],
      icon: Icons.add_chart,
      shape: TypeCategory.body.shape,
      category: TypeCategory.body,
      types: const [],
      builder: (context) => const MeasurementForm(),
    ),
    _recipe(
      WriteRecipeId.bloodPressure,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      title: 'Blood pressure',
      summary: 'Systolic and diastolic in one reading',
      description:
          'Writes a blood pressure reading in mmHg. HealthKit saves it as a blood pressure correlation of a '
          'systolic and a diastolic sample, Health Connect as one blood pressure record; reads return both '
          'as BLOOD_PRESSURE_SYSTOLIC and BLOOD_PRESSURE_DIASTOLIC data points.',
      methods: const ['writeBloodPressure'],
      types: const [HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
      builder: (context) => const BloodPressureForm(),
    ),
    _recipe(
      WriteRecipeId.bloodOxygen,
      HealthDataType.BLOOD_OXYGEN,
      title: 'Blood oxygen',
      summary: 'Oxygen saturation in percent',
      description:
          'Writes an oxygen saturation. Health Connect measures it from 0 to 100 %, while HealthKit\'s '
          'percent unit is a fraction (0.98 is 98 %): the form takes a percentage and sends the fraction '
          'on iOS, so both platforms store the same saturation.',
      methods: const ['writeBloodOxygen'],
      builder: (context) => const BloodOxygenForm(),
    ),
    _recipe(
      WriteRecipeId.meal,
      HealthDataType.NUTRITION,
      title: 'Meal',
      summary: 'A meal with its nutrients',
      description:
          'Writes a meal: its type, name, calories and macronutrients, and optionally its micronutrients, '
          'in grams. HealthKit saves a food correlation with a sample per nutrient, Health Connect one '
          'nutrition record; reads return a NUTRITION data point that lists the nutrients.',
      methods: const ['writeMeal'],
      icon: Icons.restaurant,
      builder: (context) => const MealForm(),
    ),
    _recipe(
      WriteRecipeId.workout,
      HealthDataType.WORKOUT,
      title: 'Workout',
      summary: 'Activity, totals and swimming laps',
      description:
          'Writes a workout: the activity, its times, distance and energy, a title (Health Connect), '
          'HealthKit metadata (iOS) and the pool length and laps of a swim. writeWorkoutDataUUID also '
          'returns the workout\'s UUID, which a workout route needs. On Android the distance and energy are '
          'records of their own.',
      methods: const ['writeWorkoutData', 'writeWorkoutDataUUID'],
      icon: Icons.fitness_center,
      builder: (context) => const WorkoutForm(),
    ),
    _recipe(
      WriteRecipeId.workoutRoute,
      HealthDataType.WORKOUT_ROUTE,
      title: 'Workout route',
      summary: 'A GPS route attached to a workout',
      description:
          'Records a route and attaches it to a workout: startWorkoutRoute opens a route builder, '
          'insertWorkoutRouteData adds batches of locations, finishWorkoutRoute saves the route with the '
          'UUID of a workout, and discardWorkoutRoute drops it, for example when a session is cancelled.',
      methods: const ['startWorkoutRoute', 'insertWorkoutRouteData', 'finishWorkoutRoute', 'discardWorkoutRoute'],
      types: const [HealthDataType.WORKOUT, HealthDataType.WORKOUT_ROUTE],
      builder: (context) => const WorkoutRouteForm(),
    ),
    _recipe(
      WriteRecipeId.sleepSession,
      HealthDataType.SLEEP_ASLEEP,
      title: 'Sleep session',
      summary: 'A night with its sleep stages',
      description:
          'Writes a night of sleep with its stages in one call. Health Connect stores one sleep session '
          'with its stages, title and notes; HealthKit, which has no sessions, saves in-bed samples and a '
          'sample per stage. All sleep types share one permission on each platform.',
      methods: const ['writeSleepSession'],
      icon: Icons.bedtime,
      builder: (context) => const SleepSessionForm(),
    ),
    _recipe(
      WriteRecipeId.mindfulness,
      HealthDataType.MINDFULNESS,
      title: 'Mindfulness',
      summary: 'A meditation or breathing session',
      description:
          'Writes a mindfulness session, such as a meditation. Health Connect keeps its type, title and '
          'notes; HealthKit stores a mindful session without them. Health Connect added mindfulness '
          'sessions after its first release, so Android checks isMindfulnessSessionAvailable first.',
      methods: const ['writeMindfulnessSession'],
      feature: RecipeFeature.mindfulness,
      builder: (context) => const MindfulnessForm(),
    ),
    _recipe(
      WriteRecipeId.menstruationFlow,
      HealthDataType.MENSTRUATION_FLOW,
      title: 'Menstruation flow',
      summary: 'Flow and the start of a cycle',
      description:
          'Writes the menstrual flow of a period of time and whether it starts a cycle, a flag HealthKit '
          'requires (which is why writeHealthData refuses this type on iOS). Health Connect has no "none" '
          'or "spotting" flow.',
      methods: const ['writeMenstruationFlow'],
      builder: (context) => const MenstruationFlowForm(),
    ),
    _recipe(
      WriteRecipeId.insulinDelivery,
      HealthDataType.INSULIN_DELIVERY,
      title: 'Insulin delivery',
      summary: 'Basal or bolus insulin units',
      description:
          'Writes the insulin units delivered and why (basal or bolus). HealthKit requires the delivery '
          'reason, which is why writeHealthData refuses this type on iOS. Health Connect has no insulin '
          'type.',
      methods: const ['writeInsulinDelivery'],
      platforms: const {HealthPlatformType.appleHealth},
      builder: (context) => const InsulinDeliveryForm(),
    ),
    _recipe(
      WriteRecipeId.audiogram,
      HealthDataType.AUDIOGRAM,
      title: 'Audiogram',
      summary: 'Hearing thresholds per frequency',
      description:
          'Writes a hearing test: the threshold of each ear at each frequency, in dB HL. HealthKit takes at '
          'most 30 frequencies, unique and ascending, from 0 to 30,000 Hz, with thresholds from -20 to '
          '160 dB HL.',
      methods: const ['writeAudiogram'],
      platforms: const {HealthPlatformType.appleHealth},
      builder: (context) => const AudiogramForm(),
    ),
    _recipe(
      WriteRecipeId.activityIntensity,
      HealthDataType.ACTIVITY_INTENSITY,
      title: 'Activity intensity',
      summary: 'Moderate or vigorous activity',
      description:
          'Writes a period of moderate or vigorous activity, from which Health Connect counts activity '
          'minutes. Health Connect added activity intensity in a later version, so the app checks '
          'isActivityIntensityAvailable first.',
      methods: const ['writeActivityIntensity'],
      platforms: const {HealthPlatformType.googleHealthConnect},
      feature: RecipeFeature.activityIntensity,
      builder: (context) => const ActivityIntensityForm(),
    ),
  ]);

  /// The recipe with [id].
  static WriteRecipe byId(WriteRecipeId id) => all.firstWhere((recipe) => recipe.id == id);

  /// A recipe for the typed data of [type]: its icon (unless [icon] is given), category, shape and, by
  /// default, [type] as the one type it writes.
  static WriteRecipe _recipe(
    WriteRecipeId id,
    HealthDataType type, {
    required String title,
    required String summary,
    required String description,
    required List<String> methods,
    required WidgetBuilder builder,
    IconData? icon,
    List<HealthDataType>? types,
    Set<HealthPlatformType> platforms = WriteRecipe.bothPlatforms,
    RecipeFeature? feature,
  }) => WriteRecipe(
    id: id,
    title: title,
    summary: summary,
    description: description,
    methods: methods,
    icon: icon ?? type.icon,
    shape: type.category.shape,
    category: type.category,
    types: types ?? [type],
    builder: builder,
    platforms: platforms,
    feature: feature,
  );
}
