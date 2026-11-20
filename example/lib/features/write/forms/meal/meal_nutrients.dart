/// The micronutrients `Health.writeMeal` takes, a sample of them, and one call that passes them all, as
/// the meal form and the sample data write meals.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// The micronutrients of a meal, each in grams (null for none), named as `writeMeal`'s arguments.
///
/// Both platforms take them in grams: Health Connect stores them on one nutrition record, HealthKit as
/// a sample per nutrient in a food correlation. HealthKit has no type for trans fat
/// (`fatTransMonoenoic`), and Health Connect no field for water, so each platform ignores that one.
@immutable
class MealMicronutrients {
  /// Creates a set of micronutrients; all are optional.
  const MealMicronutrients({
    this.fiber,
    this.sugar,
    this.fatSaturated,
    this.fatMonounsaturated,
    this.fatPolyunsaturated,
    this.fatUnsaturated,
    this.fatTransMonoenoic,
    this.cholesterol,
    this.caffeine,
    this.water,
    this.potassium,
    this.magnesium,
    this.phosphorus,
    this.calcium,
    this.sodium,
    this.chloride,
    this.iron,
    this.zinc,
    this.manganese,
    this.copper,
    this.selenium,
    this.iodine,
    this.chromium,
    this.molybdenum,
    this.vitaminA,
    this.b1Thiamin,
    this.b2Riboflavin,
    this.b3Niacin,
    this.b5PantothenicAcid,
    this.b6Pyridoxine,
    this.b7Biotin,
    this.b9Folate,
    this.b12Cobalamin,
    this.vitaminC,
    this.vitaminD,
    this.vitaminE,
    this.vitaminK,
  });

  /// The micronutrients of a medium banana (118 g), from food composition tables: the meal form's "add
  /// micronutrients" sample, and the sample data's snack.
  static const MealMicronutrients banana = MealMicronutrients(
    fiber: 3.1,
    sugar: 14.4,
    fatSaturated: 0.132,
    fatMonounsaturated: 0.038,
    fatPolyunsaturated: 0.086,
    potassium: 0.422,
    magnesium: 0.032,
    phosphorus: 0.026,
    calcium: 0.006,
    sodium: 0.001,
    iron: 0.00031,
    zinc: 0.00018,
    manganese: 0.00032,
    copper: 0.000092,
    selenium: 0.0000012,
    vitaminA: 0.0000035,
    b1Thiamin: 0.000037,
    b2Riboflavin: 0.000086,
    b3Niacin: 0.000785,
    b5PantothenicAcid: 0.000394,
    b6Pyridoxine: 0.000433,
    b7Biotin: 0.0000031,
    b9Folate: 0.0000236,
    vitaminC: 0.0103,
    vitaminE: 0.00012,
    vitaminK: 0.0000006,
  );

  /// Nutrients in grams.
  final double? fiber, sugar, fatSaturated, fatMonounsaturated, fatPolyunsaturated, fatUnsaturated;

  /// Nutrients in grams.
  final double? fatTransMonoenoic, cholesterol, caffeine, water;

  /// Minerals in grams.
  final double? potassium, magnesium, phosphorus, calcium, sodium, chloride, iron, zinc, manganese, copper;

  /// Trace elements in grams.
  final double? selenium, iodine, chromium, molybdenum;

  /// Vitamins in grams.
  final double? vitaminA, b1Thiamin, b2Riboflavin, b3Niacin, b5PantothenicAcid, b6Pyridoxine, b7Biotin;

  /// Vitamins in grams.
  final double? b9Folate, b12Cobalamin, vitaminC, vitaminD, vitaminE, vitaminK;

  /// The nutrients that are set, as `writeMeal` argument names and grams, for display.
  List<(String name, double grams)> get entries => [
    for (final (name, grams) in <(String, double?)>[
      ('fiber', fiber),
      ('sugar', sugar),
      ('fatSaturated', fatSaturated),
      ('fatMonounsaturated', fatMonounsaturated),
      ('fatPolyunsaturated', fatPolyunsaturated),
      ('fatUnsaturated', fatUnsaturated),
      ('fatTransMonoenoic', fatTransMonoenoic),
      ('cholesterol', cholesterol),
      ('caffeine', caffeine),
      ('water', water),
      ('potassium', potassium),
      ('magnesium', magnesium),
      ('phosphorus', phosphorus),
      ('calcium', calcium),
      ('sodium', sodium),
      ('chloride', chloride),
      ('iron', iron),
      ('zinc', zinc),
      ('manganese', manganese),
      ('copper', copper),
      ('selenium', selenium),
      ('iodine', iodine),
      ('chromium', chromium),
      ('molybdenum', molybdenum),
      ('vitaminA', vitaminA),
      ('b1Thiamin', b1Thiamin),
      ('b2Riboflavin', b2Riboflavin),
      ('b3Niacin', b3Niacin),
      ('b5PantothenicAcid', b5PantothenicAcid),
      ('b6Pyridoxine', b6Pyridoxine),
      ('b7Biotin', b7Biotin),
      ('b9Folate', b9Folate),
      ('b12Cobalamin', b12Cobalamin),
      ('vitaminC', vitaminC),
      ('vitaminD', vitaminD),
      ('vitaminE', vitaminE),
      ('vitaminK', vitaminK),
    ])
      if (grams != null) (name, grams),
  ];
}

/// Writes a meal with `Health.writeMeal`, passing the macronutrients given and every one of
/// [micronutrients], so that this one call shows all of the method's arguments.
///
/// Calories are in kcal and the other amounts in grams. On iOS a meal needs at least one nutrient that
/// HealthKit stores, or the plugin throws a `PlatformException` with code `INVALID_ARGUMENT`; on Android
/// it must end after it starts, or the plugin returns false.
Future<bool> writeMealWithNutrients(
  Health health, {
  required MealType mealType,
  required DateTime startTime,
  required DateTime endTime,
  String? name,
  double? calories,
  double? carbohydrates,
  double? protein,
  double? fat,
  MealMicronutrients micronutrients = const MealMicronutrients(),
  String? clientRecordId,
  double? clientRecordVersion,
  RecordingMethod recordingMethod = RecordingMethod.manual,
}) {
  final m = micronutrients;
  return health.writeMeal(
    mealType: mealType,
    startTime: startTime,
    endTime: endTime,
    name: name,
    caloriesConsumed: calories,
    carbohydrates: carbohydrates,
    protein: protein,
    fatTotal: fat,
    fiber: m.fiber,
    sugar: m.sugar,
    fatSaturated: m.fatSaturated,
    fatMonounsaturated: m.fatMonounsaturated,
    fatPolyunsaturated: m.fatPolyunsaturated,
    fatUnsaturated: m.fatUnsaturated,
    fatTransMonoenoic: m.fatTransMonoenoic,
    cholesterol: m.cholesterol,
    caffeine: m.caffeine,
    water: m.water,
    potassium: m.potassium,
    magnesium: m.magnesium,
    phosphorus: m.phosphorus,
    calcium: m.calcium,
    sodium: m.sodium,
    chloride: m.chloride,
    iron: m.iron,
    zinc: m.zinc,
    manganese: m.manganese,
    copper: m.copper,
    selenium: m.selenium,
    iodine: m.iodine,
    chromium: m.chromium,
    molybdenum: m.molybdenum,
    vitaminA: m.vitaminA,
    b1Thiamin: m.b1Thiamin,
    b2Riboflavin: m.b2Riboflavin,
    b3Niacin: m.b3Niacin,
    b5PantothenicAcid: m.b5PantothenicAcid,
    b6Pyridoxine: m.b6Pyridoxine,
    b7Biotin: m.b7Biotin,
    b9Folate: m.b9Folate,
    b12Cobalamin: m.b12Cobalamin,
    vitaminC: m.vitaminC,
    vitaminD: m.vitaminD,
    vitaminE: m.vitaminE,
    vitaminK: m.vitaminK,
    clientRecordId: clientRecordId,
    clientRecordVersion: clientRecordVersion,
    recordingMethod: recordingMethod,
  );
}
