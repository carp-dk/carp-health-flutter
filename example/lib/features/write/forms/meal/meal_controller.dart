/// The state of the meal form and its plugin call, `Health.writeMeal`.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import '../common/record_options.dart';
import '../common/write_form_controller.dart';
import '../common/write_outcome.dart';
import 'meal_nutrients.dart';

/// A meal to write: its type and name, when it was eaten, its energy and macronutrients, optionally a
/// sample of micronutrients, how it was recorded and, on Android, a client record id.
///
/// `writeMeal` saves one Health Connect nutrition record, or a HealthKit food correlation with a sample
/// per nutrient. Reads return it as a `NUTRITION` data point whose value lists the nutrients.
class MealController extends WriteFormController with RecordingMethodOption, ClientRecordIdOption {
  /// Creates the form's state, writing through [health]: a banana snack eaten over the 15 minutes up to
  /// [now], the sample the old example wrote.
  MealController(super.health, {required this.capabilities, DateTime? now}) {
    final current = now ?? DateTime.now();
    _end = DateTime(current.year, current.month, current.day, current.hour, current.minute);
    _start = _end.subtract(const Duration(minutes: 15));
  }

  @override
  final PlatformCapabilities capabilities;

  MealType _mealType = MealType.SNACK;
  late DateTime _start, _end;
  bool _withMicronutrients = false;

  /// The meal's name (`name`); empty for none.
  final TextEditingController name = TextEditingController(text: 'Banana');

  /// The energy in kilocalories (`caloriesConsumed`).
  final TextEditingController calories = TextEditingController(text: '105');

  /// The carbohydrates in grams (`carbohydrates`).
  final TextEditingController carbohydrates = TextEditingController(text: '27');

  /// The protein in grams (`protein`).
  final TextEditingController protein = TextEditingController(text: '1.3');

  /// The total fat in grams (`fatTotal`).
  final TextEditingController fat = TextEditingController(text: '0.4');

  /// The kind of meal (`mealType`).
  MealType get mealType => _mealType;
  set mealType(MealType value) => update(() => _mealType = value);

  /// When the meal started (`startTime`).
  DateTime get start => _start;

  /// When the meal ended (`endTime`).
  DateTime get end => _end;

  /// Sets the start and end together, as the time fields change them.
  void setSpan(DateTime start, DateTime end) => update(() {
    _start = start;
    _end = end;
  });

  /// Whether the write adds the micronutrients of a banana ([MealMicronutrients.banana]).
  bool get withMicronutrients => _withMicronutrients;
  set withMicronutrients(bool value) => update(() => _withMicronutrients = value);

  /// The micronutrients the write passes: a banana's, or none.
  MealMicronutrients get micronutrients => _withMicronutrients ? MealMicronutrients.banana : const MealMicronutrients();

  @override
  HealthDataType get type => HealthDataType.NUTRITION;

  @override
  String get description {
    final label = name.text.trim().isEmpty ? humanize(_mealType.name) : name.text.trim();
    final energy = NumberField.parse(calories.text);
    return energy == null ? label : '$label · ${formatNumber(energy)} kcal';
  }

  @override
  Future<WriteOutcome> performWrite() async {
    final id = clientRecordIdValue;
    final saved = await writeMealWithNutrients(
      health,
      mealType: _mealType,
      startTime: _start,
      endTime: _end,
      name: name.text.trim().isEmpty ? null : name.text.trim(),
      calories: _grams(calories),
      carbohydrates: _grams(carbohydrates),
      protein: _grams(protein),
      fat: _grams(fat),
      micronutrients: micronutrients,
      clientRecordId: id,
      clientRecordVersion: clientRecordVersionValue,
      recordingMethod: recordingMethod,
    );
    return WriteOutcome.fromBool('writeMeal', type, description, saved, clientRecordId: id);
  }

  @override
  void dispose() {
    for (final field in [name, calories, carbohydrates, protein, fat]) {
      field.dispose();
    }
    super.dispose();
  }

  /// The amount in [field], or null when it is empty: every nutrient of `writeMeal` is optional.
  static double? _grams(TextEditingController field) => NumberField.parse(field.text)?.toDouble();
}
