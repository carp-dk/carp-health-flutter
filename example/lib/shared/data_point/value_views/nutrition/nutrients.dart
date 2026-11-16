/// The nutrients of a meal (`NutritionHealthValue`) other than its energy and macronutrients, named and
/// grouped for display.
library;

import 'package:health/health.dart';

/// The groups the nutrition view lists nutrients in.
enum NutrientGroup {
  /// Fibre, sugar, the kinds of fat and cholesterol.
  carbsAndFats('Carbohydrates and fats'),

  /// Minerals and trace elements.
  minerals('Minerals'),

  /// Vitamins.
  vitamins('Vitamins'),

  /// Caffeine, choline and water.
  other('Other');

  /// A group with the heading [label].
  const NutrientGroup(this.label);

  /// The group's heading.
  final String label;
}

/// A nutrient field of [NutritionHealthValue]: its [label], [group] and the getter of its amount, which
/// the plugin gives in grams (null when the meal does not say).
class Nutrient {
  /// Describes the nutrient [label] of [group], read by [amountOf].
  const Nutrient(this.group, this.label, this.amountOf);

  /// The group the nutrient is listed in.
  final NutrientGroup group;

  /// The nutrient's name, such as "Vitamin C".
  final String label;

  /// The amount of the nutrient in a meal, in grams, or null when the meal does not say.
  final double? Function(NutritionHealthValue meal) amountOf;
}

/// Every nutrient field of [NutritionHealthValue] besides calories, protein, carbs and fat, which the
/// nutrition view shows as big figures, in the order listed.
final List<Nutrient> nutrients = [
  Nutrient(NutrientGroup.carbsAndFats, 'Fiber', (meal) => meal.fiber),
  Nutrient(NutrientGroup.carbsAndFats, 'Sugar', (meal) => meal.sugar),
  Nutrient(NutrientGroup.carbsAndFats, 'Saturated fat', (meal) => meal.fatSaturated),
  Nutrient(NutrientGroup.carbsAndFats, 'Unsaturated fat', (meal) => meal.fatUnsaturated),
  Nutrient(NutrientGroup.carbsAndFats, 'Monounsaturated fat', (meal) => meal.fatMonounsaturated),
  Nutrient(NutrientGroup.carbsAndFats, 'Polyunsaturated fat', (meal) => meal.fatPolyunsaturated),
  Nutrient(NutrientGroup.carbsAndFats, 'Trans fat', (meal) => meal.fatTransMonoenoic),
  Nutrient(NutrientGroup.carbsAndFats, 'Cholesterol', (meal) => meal.cholesterol),
  Nutrient(NutrientGroup.minerals, 'Calcium', (meal) => meal.calcium),
  Nutrient(NutrientGroup.minerals, 'Chloride', (meal) => meal.chloride),
  Nutrient(NutrientGroup.minerals, 'Chromium', (meal) => meal.chromium),
  Nutrient(NutrientGroup.minerals, 'Copper', (meal) => meal.copper),
  Nutrient(NutrientGroup.minerals, 'Iodine', (meal) => meal.iodine),
  Nutrient(NutrientGroup.minerals, 'Iron', (meal) => meal.iron),
  Nutrient(NutrientGroup.minerals, 'Magnesium', (meal) => meal.magnesium),
  Nutrient(NutrientGroup.minerals, 'Manganese', (meal) => meal.manganese),
  Nutrient(NutrientGroup.minerals, 'Molybdenum', (meal) => meal.molybdenum),
  Nutrient(NutrientGroup.minerals, 'Phosphorus', (meal) => meal.phosphorus),
  Nutrient(NutrientGroup.minerals, 'Potassium', (meal) => meal.potassium),
  Nutrient(NutrientGroup.minerals, 'Selenium', (meal) => meal.selenium),
  Nutrient(NutrientGroup.minerals, 'Sodium', (meal) => meal.sodium),
  Nutrient(NutrientGroup.minerals, 'Zinc', (meal) => meal.zinc),
  Nutrient(NutrientGroup.vitamins, 'Vitamin A', (meal) => meal.vitaminA),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B1 (thiamine)', (meal) => meal.b1Thiamine),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B2 (riboflavin)', (meal) => meal.b2Riboflavin),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B3 (niacin)', (meal) => meal.b3Niacin),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B5 (pantothenic acid)', (meal) => meal.b5PantothenicAcid),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B6 (pyridoxine)', (meal) => meal.b6Pyridoxine),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B7 (biotin)', (meal) => meal.b7Biotin),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B9 (folate)', (meal) => meal.b9Folate),
  Nutrient(NutrientGroup.vitamins, 'Vitamin B12 (cobalamin)', (meal) => meal.b12Cobalamin),
  Nutrient(NutrientGroup.vitamins, 'Vitamin C', (meal) => meal.vitaminC),
  Nutrient(NutrientGroup.vitamins, 'Vitamin D', (meal) => meal.vitaminD),
  Nutrient(NutrientGroup.vitamins, 'Vitamin E', (meal) => meal.vitaminE),
  Nutrient(NutrientGroup.vitamins, 'Vitamin K', (meal) => meal.vitaminK),
  Nutrient(NutrientGroup.other, 'Caffeine', (meal) => meal.caffeine),
  Nutrient(NutrientGroup.other, 'Choline', (meal) => meal.choline),
  Nutrient(NutrientGroup.other, 'Water', (meal) => meal.water),
];
