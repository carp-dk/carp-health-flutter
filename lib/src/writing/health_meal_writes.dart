part of '../../health.dart';

/// Part of [Health]: writing meals and their nutrients.
// ignore: library_private_types_in_public_api
mixin HealthMealWrites on _HealthSupport {
  /// Saves meal record into Apple Health or Health Connect.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [mealType] - the type of meal.
  ///  * [startTime] - the start time when the meal was consumed.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when the meal was consumed.
  ///    It must be equal to or later than [startTime].
  ///  * [name] - optional name information about this meal.
  ///  * [caloriesConsumed] - total calories consumed with this meal.
  ///  * [carbohydrates] - optional carbohydrates information.
  ///  * [protein] - optional protein information.
  ///  * [fatTotal] - optional total fat information.
  ///  * [caffeine] - optional caffeine information.
  ///  * [vitaminA] - optional vitamin A information.
  ///  * [b1Thiamin] - optional vitamin B1 (thiamin) information.
  ///  * [b2Riboflavin] - optional vitamin B2 (riboflavin) information.
  ///  * [b3Niacin] - optional vitamin B3 (niacin) information.
  ///  * [b5PantothenicAcid] - optional vitamin B5 (pantothenic acid) information.
  ///  * [b6Pyridoxine] - optional vitamin B6 (pyridoxine) information.
  ///  * [b7Biotin] - optional vitamin B7 (biotin) information.
  ///  * [b9Folate] - optional vitamin B9 (folate) information.
  ///  * [b12Cobalamin] - optional vitamin B12 (cobalamin) information.
  ///  * [vitaminC] - optional vitamin C information.
  ///  * [vitaminD] - optional vitamin D information.
  ///  * [vitaminE] - optional vitamin E information.
  ///  * [vitaminK] - optional vitamin K information.
  ///  * [calcium] - optional calcium information.
  ///  * [cholesterol] - optional cholesterol information.
  ///  * [chloride] - optional chloride information.
  ///  * [chromium] - optional chromium information.
  ///  * [copper] - optional copper information.
  ///  * [fatUnsaturated] - optional unsaturated fat information.
  ///  * [fatMonounsaturated] - optional monounsaturated fat information.
  ///  * [fatPolyunsaturated] - optional polyunsaturated fat information.
  ///  * [fatSaturated] - optional saturated fat information.
  ///  * [fatTransMonoenoic] - optional trans-monoenoic fat information.
  ///  * [fiber] - optional fiber information.
  ///  * [iodine] - optional iodine information.
  ///  * [iron] - optional iron information.
  ///  * [magnesium] - optional magnesium information.
  ///  * [manganese] - optional manganese information.
  ///  * [molybdenum] - optional molybdenum information.
  ///  * [phosphorus] - optional phosphorus information.
  ///  * [potassium] - optional potassium information.
  ///  * [selenium] - optional selenium information.
  ///  * [sodium] - optional sodium information.
  ///  * [sugar] - optional sugar information.
  ///  * [water] - optional water information.
  ///  * [zinc] - optional zinc information.
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeMeal({
    required MealType mealType,
    required DateTime startTime,
    required DateTime endTime,
    String? clientRecordId,
    double? clientRecordVersion,
    double? caloriesConsumed,
    double? carbohydrates,
    double? protein,
    double? fatTotal,
    String? name,
    double? caffeine,
    double? vitaminA,
    double? b1Thiamin,
    double? b2Riboflavin,
    double? b3Niacin,
    double? b5PantothenicAcid,
    double? b6Pyridoxine,
    double? b7Biotin,
    double? b9Folate,
    double? b12Cobalamin,
    double? vitaminC,
    double? vitaminD,
    double? vitaminE,
    double? vitaminK,
    double? calcium,
    double? cholesterol,
    double? chloride,
    double? chromium,
    double? copper,
    double? fatUnsaturated,
    double? fatMonounsaturated,
    double? fatPolyunsaturated,
    double? fatSaturated,
    double? fatTransMonoenoic,
    double? fiber,
    double? iodine,
    double? iron,
    double? magnesium,
    double? manganese,
    double? molybdenum,
    double? phosphorus,
    double? potassium,
    double? selenium,
    double? sodium,
    double? sugar,
    double? water,
    double? zinc,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    Map<String, dynamic> args = {
      'name': name,
      'meal_type': mealType.name,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
      'calories': caloriesConsumed,
      'carbs': carbohydrates,
      'protein': protein,
      'fat': fatTotal,
      'caffeine': caffeine,
      'vitamin_a': vitaminA,
      'b1_thiamine': b1Thiamin,
      'b2_riboflavin': b2Riboflavin,
      'b3_niacin': b3Niacin,
      'b5_pantothenic_acid': b5PantothenicAcid,
      'b6_pyridoxine': b6Pyridoxine,
      'b7_biotin': b7Biotin,
      'b9_folate': b9Folate,
      'b12_cobalamin': b12Cobalamin,
      'vitamin_c': vitaminC,
      'vitamin_d': vitaminD,
      'vitamin_e': vitaminE,
      'vitamin_k': vitaminK,
      'calcium': calcium,
      'cholesterol': cholesterol,
      'chloride': chloride,
      'chromium': chromium,
      'copper': copper,
      'fat_unsaturated': fatUnsaturated,
      'fat_monounsaturated': fatMonounsaturated,
      'fat_polyunsaturated': fatPolyunsaturated,
      'fat_saturated': fatSaturated,
      'fat_trans_monoenoic': fatTransMonoenoic,
      'fiber': fiber,
      'iodine': iodine,
      'iron': iron,
      'magnesium': magnesium,
      'manganese': manganese,
      'molybdenum': molybdenum,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'selenium': selenium,
      'sodium': sodium,
      'sugar': sugar,
      'water': water,
      'zinc': zinc,
      'recordingMethod': recordingMethod.toInt(),
    };
    bool? success = await Health._channel.invokeMethod('writeMeal', args);
    return success ?? false;
  }
}
