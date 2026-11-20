/// The form of the Measurement recipe: writes one value of any writable type with
/// `Health.writeHealthData`, or with `Health.writeHealthDataUUID`, which also returns the new record's UUID.
///
/// The form shows every argument of the two methods: the type (from `TypeCatalog.writableTypes`), the
/// value and, on iOS, its unit, the start and end, the recording method and, on Android, the client
/// record id and version.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/field_pair.dart';
import 'form_kit/form_note.dart';
import 'form_kit/time_span_fields.dart';
import 'measurement/measurement_controller.dart';
import 'measurement/measurement_type_field.dart';

/// Writes one value of a data type ([MeasurementController]): a heart rate over the last 20 minutes by
/// default, written with `writeHealthDataUUID` so the record can be viewed and deleted right after.
class MeasurementForm extends StatefulWidget {
  /// Creates the form.
  const MeasurementForm({super.key});

  @override
  State<MeasurementForm> createState() => _MeasurementFormState();
}

class _MeasurementFormState extends WriteFormState<MeasurementForm, MeasurementController> {
  @override
  MeasurementController createController(AppServices services) => MeasurementController(
    services.health,
    capabilities: services.capabilities,
    types: services.catalog.writableTypes,
  );

  @override
  Widget buildFields(BuildContext context) {
    final c = controller;
    final type = c.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Data type',
                parameter: 'type',
                caption: '${c.types.length} types here; the others have their own write methods or are read-only.',
                child: MeasurementTypeField(type: type, types: c.types, onChanged: (type) => c.type = type),
              ),
              FormSection(
                title: 'Value',
                parameter: c.isIOS ? 'value · unit' : 'value',
                caption: _valueCaption(c),
                child: _valueFields(c),
              ),
              FormSection(
                title: 'Time',
                parameter: 'startTime · endTime',
                caption: c.needsDuration
                    ? (c.isAndroid
                          ? 'Health Connect needs a duration here: an end at the start throws INVALID_ARGUMENT.'
                          : 'HealthKit needs ${type.label.toLowerCase()} to last at least a millisecond.')
                    : 'endTime defaults to startTime, an instant.',
                child: TimeSpanFields(
                  start: c.start,
                  end: c.end,
                  onChanged: c.setSpan,
                  presets: const [Duration.zero, Duration(minutes: 5), Duration(minutes: 20), Duration(hours: 1)],
                  allowInstant: !c.needsDuration,
                ),
              ),
              RecordingMethodSection(options: c),
              ClientRecordIdSection(options: c),
              FormSection(
                title: 'Write method',
                parameter: c.method.name,
                caption: c.method.returns,
                child: ConnectedButtonGroup<MeasurementWriteMethod>(
                  segments: const [
                    ButtonGroupSegment(
                      value: MeasurementWriteMethod.writeHealthData,
                      label: 'Bool',
                      icon: Icons.check_circle_outline,
                    ),
                    ButtonGroupSegment(
                      value: MeasurementWriteMethod.writeHealthDataUUID,
                      label: 'UUID',
                      icon: Icons.fingerprint,
                    ),
                  ],
                  selected: c.method,
                  onSelected: (method) => c.method = method,
                ),
              ),
            ],
          ),
        ),
        WriteButton(label: 'Write ${type.label.toLowerCase()}', icon: type.icon, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }

  /// What the value means on this platform, with the value as it will be stored.
  String _valueCaption(MeasurementController c) {
    if (c.ignoresValue) {
      return c.type == HealthDataType.MINDFULNESS
          ? 'The plugin sends 0: a session is its time span.'
          : 'The plugin sends 0: the type is the value.';
    }
    final stored = c.description;
    if (c.isAndroid) return 'Writes $stored. Health Connect uses its own unit, so unit is ignored.';
    return c.isFraction
        ? 'Writes $stored. HealthKit percentages are fractions: 0.2 is 20 %.'
        : 'Writes $stored. HealthKit converts from any unit of its kind.';
  }

  /// The value and, on iOS, its unit; or a note that the type needs none.
  Widget _valueFields(MeasurementController c) {
    if (c.ignoresValue) return const FormNote(text: 'No value needed');
    final symbol = formatUnit(c.type.defaultUnit);
    final valueField = NumberField(
      label: c.type.label,
      controller: c.value,
      unit: c.isIOS || symbol.isEmpty ? null : symbol,
      // The caption shows the value as it will be stored.
      onChanged: (_) => c.valueEdited(),
    );
    if (!c.isIOS) return valueField;
    return FieldPair(
      first: valueField,
      second: EnumDropdownField<HealthDataUnit>(
        // A new type brings new units: a new key resets the menu's selection.
        key: ValueKey(c.type),
        label: 'Unit',
        value: c.unit,
        values: c.units,
        labelOf: (unit) => formatUnit(unit).isEmpty ? unit.name : '${formatUnit(unit)} · ${unit.name}',
        onChanged: (unit) => c.unit = unit,
      ),
    );
  }
}
