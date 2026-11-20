part of '../../health.dart';

/// A [HealthValue] object for nutrition.
///
/// Parameters:
///  * [mealType] - the type of meal
///  * [name] - the name of the food
///  * [b1Thiamine] - the amount of thiamine (B1) in grams
///  * [b2Riboflavin] - the amount of riboflavin (B2) in grams
///  * [b3Niacin] - the amount of niacin (B3) in grams
///  * [b5PantothenicAcid] - the amount of pantothenic acid (B5) in grams
///  * [b6Pyridoxine] - the amount of pyridoxine (B6) in grams
///  * [b7Biotin] - the amount of biotin (B7) in grams
///  * [b9Folate] - the amount of folate (B9) in grams
///  * [b12Cobalamin] - the amount of cobalamin (B12) in grams
///  * [caffeine] - the amount of caffeine in grams
///  * [calcium] - the amount of calcium in grams
///  * [calories] - the amount of calories in kcal
///  * [carbs] - the amount of carbs in grams
///  * [chloride] - the amount of chloride in grams
///  * [cholesterol] - the amount of cholesterol in grams
///  * [choline] - the amount of choline in grams
///  * [chromium] - the amount of chromium in grams
///  * [copper] - the amount of copper in grams
///  * [fat] - the amount of fat in grams
///  * [fatMonounsaturated] - the amount of monounsaturated fat in grams
///  * [fatPolyunsaturated] - the amount of polyunsaturated fat in grams
///  * [fatSaturated] - the amount of saturated fat in grams
///  * [fatTransMonoenoic] - the amount of trans-monoenoic fat in grams
///  * [fatUnsaturated] - the amount of unsaturated fat in grams
///  * [fiber] - the amount of fiber in grams
///  * [iodine] - the amount of iodine in grams
///  * [iron] - the amount of iron in grams
///  * [magnesium] - the amount of magnesium in grams
///  * [manganese] - the amount of manganese in grams
///  * [molybdenum] - the amount of molybdenum in grams
///  * [phosphorus] - the amount of phosphorus in grams
///  * [potassium] - the amount of potassium in grams
///  * [protein] - the amount of protein in grams
///  * [selenium] - the amount of selenium in grams
///  * [sodium] - the amount of sodium in grams
///  * [sugar] - the amount of sugar in grams
///  * [vitaminA] - the amount of vitamin A in grams
///  * [vitaminC] - the amount of vitamin C in grams
///  * [vitaminD] - the amount of vitamin D in grams
///  * [vitaminE] - the amount of vitamin E in grams
///  * [vitaminK] - the amount of vitamin K in grams
///  * [water] - the amount of water in grams
///  * [zinc] - the amount of zinc in grams

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class NutritionHealthValue extends HealthValue {
  /// The name of the food.
  String? name;

  /// The type of meal.
  @JsonKey(name: 'meal_type')
  String? mealType;

  /// The amount of calories in kcal.
  double? calories;

  /// The amount of protein in grams.
  double? protein;

  /// The amount of fat in grams.
  double? fat;

  /// The amount of carbs in grams.
  double? carbs;

  /// The amount of caffeine in grams.
  double? caffeine;

  /// The amount of vitamin A in grams.
  @JsonKey(name: 'vitamin_a')
  double? vitaminA;

  /// The amount of thiamine (B1) in grams.
  @JsonKey(name: 'b1_thiamine')
  double? b1Thiamine;

  /// The amount of riboflavin (B2) in grams.
  @JsonKey(name: 'b2_riboflavin')
  double? b2Riboflavin;

  /// The amount of niacin (B3) in grams.
  @JsonKey(name: 'b3_niacin')
  double? b3Niacin;

  /// The amount of pantothenic acid (B5) in grams.
  @JsonKey(name: 'b5_pantothenic_acid')
  double? b5PantothenicAcid;

  /// The amount of pyridoxine (B6) in grams.
  @JsonKey(name: 'b6_pyridoxine')
  double? b6Pyridoxine;

  /// The amount of biotin (B7) in grams.
  @JsonKey(name: 'b7_biotin')
  double? b7Biotin;

  /// The amount of folate (B9) in grams.
  @JsonKey(name: 'b9_folate')
  double? b9Folate;

  /// The amount of cobalamin (B12) in grams.
  @JsonKey(name: 'b12_cobalamin')
  double? b12Cobalamin;

  /// The amount of vitamin C in grams.
  @JsonKey(name: 'vitamin_c')
  double? vitaminC;

  /// The amount of vitamin D in grams.
  @JsonKey(name: 'vitamin_d')
  double? vitaminD;

  /// The amount of vitamin E in grams.
  @JsonKey(name: 'vitamin_e')
  double? vitaminE;

  /// The amount of vitamin K in grams.
  @JsonKey(name: 'vitamin_k')
  double? vitaminK;

  /// The amount of calcium in grams.
  double? calcium;

  /// The amount of chloride in grams.
  double? chloride;

  /// The amount of cholesterol in grams.
  double? cholesterol;

  /// The amount of choline in grams.
  double? choline;

  /// The amount of chromium in grams.
  double? chromium;

  /// The amount of copper in grams.
  double? copper;

  /// The amount of unsaturated fat in grams.
  @JsonKey(name: 'fat_unsaturated')
  double? fatUnsaturated;

  /// The amount of monounsaturated fat in grams.
  @JsonKey(name: 'fat_monounsaturated')
  double? fatMonounsaturated;

  /// The amount of polyunsaturated fat in grams.
  @JsonKey(name: 'fat_polyunsaturated')
  double? fatPolyunsaturated;

  /// The amount of saturated fat in grams.
  @JsonKey(name: 'fat_saturated')
  double? fatSaturated;

  /// The amount of trans-monoenoic fat in grams.
  @JsonKey(name: 'fat_trans_monoenoic')
  double? fatTransMonoenoic;

  /// The amount of fiber in grams.
  double? fiber;

  /// The amount of iodine in grams.
  double? iodine;

  /// The amount of iron in grams.
  double? iron;

  /// The amount of magnesium in grams.
  double? magnesium;

  /// The amount of manganese in grams.
  double? manganese;

  /// The amount of molybdenum in grams.
  double? molybdenum;

  /// The amount of phosphorus in grams.
  double? phosphorus;

  /// The amount of potassium in grams.
  double? potassium;

  /// The amount of selenium in grams.
  double? selenium;

  /// The amount of sodium in grams.
  double? sodium;

  /// The amount of sugar in grams.
  double? sugar;

  /// The amount of water in grams.
  double? water;

  /// The amount of zinc in grams.
  double? zinc;

  NutritionHealthValue({
    this.name,
    this.mealType,
    this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.caffeine,
    this.vitaminA,
    this.b1Thiamine,
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
    this.calcium,
    this.chloride,
    this.cholesterol,
    this.choline,
    this.chromium,
    this.copper,
    this.fatUnsaturated,
    this.fatMonounsaturated,
    this.fatPolyunsaturated,
    this.fatSaturated,
    this.fatTransMonoenoic,
    this.fiber,
    this.iodine,
    this.iron,
    this.magnesium,
    this.manganese,
    this.molybdenum,
    this.phosphorus,
    this.potassium,
    this.selenium,
    this.sodium,
    this.sugar,
    this.water,
    this.zinc,
  });

  @override
  Function get fromJsonFunction => _$NutritionHealthValueFromJson;
  factory NutritionHealthValue.fromJson(Map<String, dynamic> json) => _$NutritionHealthValueFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$NutritionHealthValueToJson(this);

  /// Create a [NutritionHealthValue] based on a health data point from native data format.
  factory NutritionHealthValue.fromHealthDataPoint(dynamic dataPoint) {
    dataPoint = dataPoint as Map<Object?, Object?>;
    // Convert to Map<String, Object?> and ensure all expected fields are present
    final Map<String, Object?> dataPointMap = {};

    // Add all entries from the native data
    dataPoint.forEach((key, value) {
      if (key != null) {
        dataPointMap[key as String] = value;
      }
    });

    return _$NutritionHealthValueFromJson(dataPointMap);
  }

  @override
  String toString() =>
      '$runtimeType - ${_fields.entries.map((field) => '${field.key}: ${field.value}').join(',\n    ')}';

  @override
  bool operator ==(Object other) => other is NutritionHealthValue && mapEquals(_fields, other._fields);

  @override
  int get hashCode => Object.hashAll(_fields.values);
}
