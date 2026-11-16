/// Picks the view for the kind of value a data point holds.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'activity_intensity_value_view.dart';
import 'audiogram_value_view.dart';
import 'ecg/ecg_value_view.dart';
import 'insulin_value_view.dart';
import 'menstruation_value_view.dart';
import 'numeric_value_view.dart';
import 'nutrition/nutrition_value_view.dart';
import 'route/route_value_view.dart';
import 'skin_temperature_value_view.dart';
import 'workout/workout_value_view.dart';

/// The details of [point]'s value, by its kind of [HealthValue].
///
/// Most types read as a [NumericHealthValue]; workouts, meals, audiograms, ECGs, routes, menstrual
/// flow, insulin, skin temperature and activity intensity have values of their own. The data point
/// sheet and Read's lookup by UUID both show a point's value with this widget.
class TypedValueView extends StatelessWidget {
  /// Creates the view of [point]'s value.
  const TypedValueView({super.key, required this.point});

  /// The data point whose value to show.
  final HealthDataPoint point;

  @override
  Widget build(BuildContext context) => switch (point.value) {
    final NumericHealthValue value => NumericValueView(point: point, value: value),
    final WorkoutHealthValue value => WorkoutValueView(point: point, value: value),
    final NutritionHealthValue value => NutritionValueView(value: value),
    final AudiogramHealthValue value => AudiogramValueView(value: value),
    final ElectrocardiogramHealthValue value => EcgValueView(value: value),
    final WorkoutRouteHealthValue value => RouteValueView(point: point, value: value),
    final MenstruationFlowHealthValue value => MenstruationValueView(value: value),
    final InsulinDeliveryHealthValue value => InsulinValueView(value: value),
    final SkinTemperatureHealthValue value => SkinTemperatureValueView(value: value),
    final ActivityIntensityHealthValue value => ActivityIntensityValueView(value: value),
    // A value kind a newer plugin version adds: the raw JSON section still shows it.
    _ => const SizedBox.shrink(),
  };
}
