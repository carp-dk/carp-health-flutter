/// The details of a meal: its energy and macronutrients as big figures, then every other nutrient.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';
import 'package:health_example/shared/data_point/layout/metric_grid.dart';

import 'nutrients.dart';

/// A [NutritionHealthValue], as `writeMeal` writes it: the food's name and meal type, calories,
/// protein, carbohydrates and fat as figures, and the other [nutrients] the meal has, by group.
///
/// The plugin gives every nutrient in grams; small amounts show in milligrams or micrograms.
class NutritionValueView extends StatelessWidget {
  /// Creates the view of [value].
  const NutritionValueView({super.key, required this.value});

  /// The meal.
  final NutritionHealthValue value;

  @override
  Widget build(BuildContext context) {
    final mealType = value.mealType;
    final figures = [
      if (value.calories case final calories?)
        MetricTile(
          label: 'Energy',
          value: formatNumber(calories, maxDecimals: 0),
          unit: 'kcal',
          icon: Icons.local_fire_department_outlined,
          shape: ExpressiveShape.sunny,
        ),
      ?_macro('Protein', value.protein, Icons.egg_outlined, ExpressiveShape.cookie4),
      ?_macro('Carbohydrates', value.carbs, Icons.bakery_dining_outlined, ExpressiveShape.cookie12),
      ?_macro('Fat', value.fat, Icons.water_drop_outlined, ExpressiveShape.oval),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailSection(
          title: 'Meal',
          children: [
            DetailField(label: 'Food', value: value.name ?? 'No name'),
            DetailField(label: 'Meal type', value: mealType == null ? 'Not set' : humanize(mealType)),
          ],
        ),
        if (figures.isNotEmpty) ...[const SizedBox(height: 8), MetricGrid(tiles: figures)],
        for (final group in NutrientGroup.values) ?_group(group),
      ],
    );
  }

  /// A tile for a macronutrient the meal has.
  MetricTile? _macro(String label, double? grams, IconData icon, ExpressiveShape shape) => grams == null
      ? null
      : MetricTile(label: label, value: formatNumber(grams, maxDecimals: 1), unit: 'g', icon: icon, shape: shape);

  /// The section of [group]'s nutrients the meal has, or null when it has none of them.
  Widget? _group(NutrientGroup group) {
    final fields = [
      for (final nutrient in nutrients.where((nutrient) => nutrient.group == group))
        if (nutrient.amountOf(value) case final grams?)
          DetailField(label: nutrient.label, value: formatNumericValue(grams, HealthDataUnit.GRAM)),
    ];
    return fields.isEmpty ? null : DetailSection(title: group.label, children: fields);
  }
}
