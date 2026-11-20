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
import 'forms/sexual_activity_form.dart';
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
      description:
          'Writes one value of a data type, such as a heart rate. The UUID variant returns the new record\'s id '
          '(empty when nothing was saved). The unit is iOS only; types Health Connect stores as intervals, such as '
          'steps, need an end after the start.',
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
      description:
          'Writes one reading in mmHg. HealthKit saves a correlation of a systolic and a diastolic sample, Health '
          'Connect one record; reads return both as data points.',
      methods: const ['writeBloodPressure'],
      types: const [HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
      builder: (context) => const BloodPressureForm(),
    ),
    _recipe(
      WriteRecipeId.bloodOxygen,
      HealthDataType.BLOOD_OXYGEN,
      title: 'Blood oxygen',
      description:
          'Writes an oxygen saturation in percent. HealthKit stores it as a fraction (0.98 is 98 %), so the form '
          'sends the fraction on iOS.',
      methods: const ['writeBloodOxygen'],
      builder: (context) => const BloodOxygenForm(),
    ),
    _recipe(
      WriteRecipeId.meal,
      HealthDataType.NUTRITION,
      title: 'Meal',
      description:
          'Writes a meal with its calories and nutrients in grams. HealthKit saves a food correlation, Health Connect '
          'one nutrition record; reads return one NUTRITION point.',
      methods: const ['writeMeal'],
      icon: Icons.restaurant,
      builder: (context) => const MealForm(),
    ),
    _recipe(
      WriteRecipeId.workout,
      HealthDataType.WORKOUT,
      title: 'Workout',
      description:
          'Writes a workout with its distance, energy and, for a swim, pool length and laps. The UUID variant returns '
          'the id a workout route needs. On Android the distance and energy are records of their own.',
      methods: const ['writeWorkoutData', 'writeWorkoutDataUUID'],
      icon: Icons.fitness_center,
      builder: (context) => const WorkoutForm(),
    ),
    _recipe(
      WriteRecipeId.workoutRoute,
      HealthDataType.WORKOUT_ROUTE,
      title: 'Workout route',
      description:
          'Records a GPS route and attaches it to a workout: start a builder, add batches of locations, then finish '
          'with the workout\'s UUID. Discarding drops the route instead.',
      methods: const ['startWorkoutRoute', 'insertWorkoutRouteData', 'finishWorkoutRoute', 'discardWorkoutRoute'],
      types: const [HealthDataType.WORKOUT, HealthDataType.WORKOUT_ROUTE],
      builder: (context) => const WorkoutRouteForm(),
    ),
    _recipe(
      WriteRecipeId.sleepSession,
      HealthDataType.SLEEP_ASLEEP,
      title: 'Sleep session',
      description:
          'Writes a night of sleep with its stages in one call. Health Connect stores one session; HealthKit, which '
          'has no sessions, saves in-bed and stage samples. All sleep types share one permission.',
      methods: const ['writeSleepSession'],
      icon: Icons.bedtime,
      builder: (context) => const SleepSessionForm(),
    ),
    _recipe(
      WriteRecipeId.mindfulness,
      HealthDataType.MINDFULNESS,
      title: 'Mindfulness',
      description:
          'Writes a mindfulness session, such as a meditation. Health Connect keeps its type, title and notes; '
          'HealthKit does not. Android checks that Health Connect has the feature first.',
      methods: const ['writeMindfulnessSession'],
      feature: RecipeFeature.mindfulness,
      builder: (context) => const MindfulnessForm(),
    ),
    _recipe(
      WriteRecipeId.menstruationFlow,
      HealthDataType.MENSTRUATION_FLOW,
      title: 'Menstruation flow',
      description:
          'Writes the flow of a period of time and whether it starts a cycle, which HealthKit requires (so '
          'writeHealthData refuses this type on iOS). Health Connect has no "none" or "spotting" flow.',
      methods: const ['writeMenstruationFlow'],
      builder: (context) => const MenstruationFlowForm(),
    ),
    _recipe(
      WriteRecipeId.sexualActivity,
      HealthDataType.SEXUAL_ACTIVITY,
      title: 'Sexual activity',
      description:
          'Writes a sexual activity entry with whether protection was used. Health Connect stores it as a '
          'SexualActivityRecord; HealthKit stores a sexualActivity category sample with optional protection metadata.',
      methods: const ['writeSexualActivity'],
      builder: (context) => const SexualActivityForm(),
    ),
    _recipe(
      WriteRecipeId.insulinDelivery,
      HealthDataType.INSULIN_DELIVERY,
      title: 'Insulin delivery',
      description:
          'Writes the insulin units delivered, basal or bolus. HealthKit requires the reason, so writeHealthData '
          'refuses this type on iOS.',
      methods: const ['writeInsulinDelivery'],
      platforms: const {HealthPlatformType.appleHealth},
      builder: (context) => const InsulinDeliveryForm(),
    ),
    _recipe(
      WriteRecipeId.audiogram,
      HealthDataType.AUDIOGRAM,
      title: 'Audiogram',
      description:
          'Writes the hearing threshold of each ear per frequency, in dB HL. HealthKit takes at most 30 ascending '
          'frequencies up to 30,000 Hz, with thresholds from -20 to 160 dB HL.',
      methods: const ['writeAudiogram'],
      platforms: const {HealthPlatformType.appleHealth},
      builder: (context) => const AudiogramForm(),
    ),
    _recipe(
      WriteRecipeId.activityIntensity,
      HealthDataType.ACTIVITY_INTENSITY,
      title: 'Activity intensity',
      description:
          'Writes a period of moderate or vigorous activity, from which Health Connect counts activity minutes. Older '
          'Health Connect versions lack it, so the app checks first.',
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
