/// The groups the example sorts the plugin's 155 `HealthDataType`s into, for pickers, permission
/// scopes and the type catalog. `HealthDataTypeInfo.category` assigns each type to one.
library;

import 'package:flutter/material.dart';

/// A group of related health data types, with a [label] and an [icon].
enum TypeCategory {
  /// Steps, distance, energy, floors and Apple's activity rings.
  activity('Activity', Icons.directions_run),

  /// Weight, height, body composition and body temperature.
  body('Body measurements', Icons.accessibility_new),

  /// Heart, blood and respiratory measurements.
  vitals('Heart & vitals', Icons.monitor_heart),

  /// Sleep sessions, sleep stages and overnight measurements.
  sleep('Sleep', Icons.bedtime),

  /// Meals, water and single nutrients.
  nutrition('Nutrition', Icons.restaurant),

  /// Mindfulness sessions such as meditation.
  mindfulness('Mindfulness', Icons.self_improvement),

  /// Menstruation and basal body temperature.
  cycle('Cycle tracking', Icons.water_drop),

  /// Workouts, their routes and performance measurements such as power and cadence.
  workouts('Workouts', Icons.fitness_center),

  /// Walking quality, stair speed and falls (HealthKit's mobility metrics).
  mobility('Mobility', Icons.accessible_forward),

  /// Audiograms and sound exposure.
  hearing('Hearing', Icons.hearing),

  /// Daylight, UV and water conditions.
  environment('Environment', Icons.wb_sunny),

  /// Headaches by severity.
  symptoms('Symptoms', Icons.sick),

  /// HealthKit characteristics: one value each that the user sets in the Health app.
  characteristics('Characteristics', Icons.badge),

  /// Everything else.
  other('Other', Icons.category);

  const TypeCategory(this.label, this.icon);

  /// The category's name, such as "Heart & vitals".
  final String label;

  /// A Material icon for the category.
  final IconData icon;
}
