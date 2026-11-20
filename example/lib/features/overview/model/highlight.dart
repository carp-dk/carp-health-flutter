/// The highlights the overview shows as metric tiles, and the data types each one reads.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

import 'sleep_summary.dart';

/// One highlight of the overview: a metric tile with its [label], [icon] and [shape], read with one
/// plugin call ([method]).
enum Highlight {
  /// The steps since midnight: `getTotalStepsInInterval`.
  steps('Steps', Icons.directions_walk, ExpressiveShape.sunny, 'getTotalStepsInInterval'),

  /// The newest heart rate of the last 30 days: `getHealthDataFromTypes` with `limit: 1`.
  heartRate('Heart rate', Icons.favorite, ExpressiveShape.cookie9, 'getHealthDataFromTypes (limit: 1)'),

  /// The newest weight of the last year: `getHealthDataFromTypes` with `limit: 1`.
  weight('Weight', Icons.monitor_weight, ExpressiveShape.cookie4, 'getHealthDataFromTypes (limit: 1)'),

  /// The active energy burned since midnight: `getHealthIntervalDataFromTypes`.
  activeEnergy(
    'Active energy',
    Icons.local_fire_department,
    ExpressiveShape.verySunny,
    'getHealthIntervalDataFromTypes',
  ),

  /// Last night's sleep: `getHealthIntervalDataFromTypes` over the sleep types.
  sleep('Sleep', Icons.bedtime, ExpressiveShape.oval, 'getHealthIntervalDataFromTypes'),

  /// The workouts since Monday: `getHealthDataFromTypes`.
  workouts('Workouts', Icons.fitness_center, ExpressiveShape.softBurst, 'getHealthDataFromTypes');

  const Highlight(this.label, this.icon, this.shape, this.method);

  /// The tile's label, such as "Steps today": short enough for a two-column grid on a phone.
  final String label;

  /// The icon in the tile's shape.
  final IconData icon;

  /// The shape behind the icon.
  final ExpressiveShape shape;

  /// The plugin method that reads the highlight.
  final String method;

  /// The data types the highlight reads on [platform]: what a tile without access asks for.
  ///
  /// Sleep reads the in-bed type and the asleep stages ([SleepSummary.typesFor]), which share one
  /// permission on each platform.
  List<HealthDataType> typesOn(HealthPlatformType platform) => switch (this) {
    steps => const [HealthDataType.STEPS],
    heartRate => const [HealthDataType.HEART_RATE],
    weight => const [HealthDataType.WEIGHT],
    activeEnergy => const [HealthDataType.ACTIVE_ENERGY_BURNED],
    sleep => SleepSummary.typesFor(platform),
    workouts => const [HealthDataType.WORKOUT],
  };

  /// The overview's core types on [platform]: the types of every highlight, in order, each once. The
  /// hero card's "Grant access" requests them with `requestAuthorization`.
  static List<HealthDataType> coreTypes(HealthPlatformType platform) =>
      List.unmodifiable({for (final highlight in values) ...highlight.typesOn(platform)});
}
