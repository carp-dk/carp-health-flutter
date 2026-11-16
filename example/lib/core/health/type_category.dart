/// The groups the example sorts the plugin's 155 `HealthDataType`s into, for pickers, permission
/// scopes and the type catalog. `HealthDataTypeInfo.category` assigns each type to one.
library;

import 'package:flutter/material.dart';

/// A group of related health data types, with a [label], an [icon] and a one-line [description].
enum TypeCategory {
  /// Steps, distance, energy, floors and Apple's activity rings.
  activity('Activity', Icons.directions_run, 'Steps, distance, energy, floors and activity rings'),

  /// Weight, height, body composition and body temperature.
  body('Body measurements', Icons.accessibility_new, 'Weight, height, body composition and temperature'),

  /// Heart, blood and respiratory measurements.
  vitals('Heart & vitals', Icons.monitor_heart, 'Heart rate, blood pressure, oxygen, glucose and breathing'),

  /// Sleep sessions, sleep stages and overnight measurements.
  sleep('Sleep', Icons.bedtime, 'Sleep sessions, sleep stages and overnight measurements'),

  /// Meals, water and single nutrients.
  nutrition('Nutrition', Icons.restaurant, 'Meals, water and nutrients'),

  /// Mindfulness sessions such as meditation.
  mindfulness('Mindfulness', Icons.self_improvement, 'Mindful sessions such as meditation'),

  /// Menstruation and basal body temperature.
  cycle('Cycle tracking', Icons.water_drop, 'Menstruation and basal body temperature'),

  /// Workouts, their routes and performance measurements such as power and cadence.
  workouts('Workouts', Icons.fitness_center, 'Workouts, routes, power, cadence and speed'),

  /// Walking quality, stair speed and falls (HealthKit's mobility metrics).
  mobility('Mobility', Icons.accessible_forward, 'Walking quality, stair speed and falls'),

  /// Audiograms and sound exposure.
  hearing('Hearing', Icons.hearing, 'Audiograms and sound exposure'),

  /// Daylight, UV and water conditions.
  environment('Environment', Icons.wb_sunny, 'Daylight, UV exposure and water conditions'),

  /// Headaches by severity.
  symptoms('Symptoms', Icons.sick, 'Headaches by severity'),

  /// HealthKit characteristics: one value each that the user sets in the Health app.
  characteristics('Characteristics', Icons.badge, 'Biological sex, date of birth and blood type'),

  /// Everything else.
  other('Other', Icons.category, 'Insulin, alcohol and electrodermal activity');

  const TypeCategory(this.label, this.icon, this.description);

  /// The category's name, such as "Heart & vitals".
  final String label;

  /// A Material icon for the category.
  final IconData icon;

  /// What the category holds, in one line.
  final String description;
}
