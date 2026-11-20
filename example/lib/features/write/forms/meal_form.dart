/// The form of the Meal recipe: writes a meal with its nutrients with `Health.writeMeal`.
///
/// The form shows the method's arguments: the meal type and name, the start and end, the energy and
/// macronutrients, an "add micronutrients" sample (a banana's, which passes many of the 37 optional
/// nutrient arguments), the recording method and, on Android, the client record id and version.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/choice_tiles.dart';
import 'form_kit/field_pair.dart';
import 'form_kit/time_span_fields.dart';
import 'meal/meal_controller.dart';

/// Writes a meal ([MealController]): a banana snack by default, the old example's sample.
class MealForm extends StatefulWidget {
  /// Creates the form.
  const MealForm({super.key});

  @override
  State<MealForm> createState() => _MealFormState();
}

class _MealFormState extends WriteFormState<MealForm, MealController> {
  /// The meal types, each with an icon.
  static const List<ChoiceTile<MealType>> _mealTypes = [
    ChoiceTile(value: MealType.BREAKFAST, label: 'Breakfast', icon: Icons.free_breakfast),
    ChoiceTile(value: MealType.LUNCH, label: 'Lunch', icon: Icons.lunch_dining),
    ChoiceTile(value: MealType.DINNER, label: 'Dinner', icon: Icons.dinner_dining),
    ChoiceTile(value: MealType.SNACK, label: 'Snack', icon: Icons.cookie_outlined),
    ChoiceTile(value: MealType.UNKNOWN, label: 'Unknown', icon: Icons.restaurant),
  ];

  @override
  MealController createController(AppServices services) =>
      MealController(services.health, capabilities: services.capabilities);

  @override
  Widget buildFields(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Meal',
                parameter: 'mealType · name',
                caption: 'The name is optional; both platforms keep it.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    ChoiceTiles<MealType>(
                      choices: _mealTypes,
                      selected: c.mealType,
                      onSelected: (type) => c.mealType = type,
                      selectedShape: ExpressiveShape.cookie12,
                      minTileWidth: 104,
                    ),
                    TextFormField(
                      controller: c.name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.label_outline)),
                    ),
                  ],
                ),
              ),
              FormSection(
                title: 'Time',
                parameter: 'startTime · endTime',
                caption: 'On Android a meal must end after it starts, or nothing is saved.',
                child: TimeSpanFields(
                  start: c.start,
                  end: c.end,
                  onChanged: c.setSpan,
                  presets: const [Duration(minutes: 5), Duration(minutes: 15), Duration(minutes: 30)],
                ),
              ),
              FormSection(
                title: 'Energy and macros',
                parameter: 'caloriesConsumed · carbohydrates · protein · fatTotal',
                caption:
                    'Optional, in kcal and grams. On iOS at least one nutrient is needed (INVALID_ARGUMENT otherwise).',
                child: Column(
                  spacing: 16,
                  children: [
                    FieldPair(
                      first: NumberField(label: 'Energy', controller: c.calories, unit: 'kcal', isRequired: false),
                      second: NumberField(label: 'Carbs', controller: c.carbohydrates, unit: 'g', isRequired: false),
                    ),
                    FieldPair(
                      first: NumberField(label: 'Protein', controller: c.protein, unit: 'g', isRequired: false),
                      second: NumberField(label: 'Fat', controller: c.fat, unit: 'g', isRequired: false),
                    ),
                  ],
                ),
              ),
              FormSection(
                title: 'Micronutrients',
                parameter: 'fiber · sugar · potassium · vitaminC · …',
                caption: "A banana's, in grams. HealthKit has no trans fat and Health Connect no water.",
                child: _Micronutrients(controller: c),
              ),
              RecordingMethodSection(options: c),
              ClientRecordIdSection(options: c),
            ],
          ),
        ),
        WriteButton(label: 'Write meal', icon: Icons.restaurant, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}

/// The micronutrients switch and, when it is on, the nutrients the write passes.
class _Micronutrients extends StatelessWidget {
  const _Micronutrients({required this.controller});

  final MealController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = controller.micronutrients.entries;
    const motion = ExpressiveMotion.spatialDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: controller.withMicronutrients,
          onChanged: (value) => controller.withMicronutrients = value,
          title: const Text('Banana micronutrients'),
          subtitle: entries.isEmpty ? null : Text('${entries.length} nutrients'),
        ),
        // The chips spring open under the switch.
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: entries.isEmpty
              ? const SizedBox(width: double.infinity)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (name, grams) in entries)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${humanize(name)} ${formatNumericValue(grams, HealthDataUnit.GRAM)}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
