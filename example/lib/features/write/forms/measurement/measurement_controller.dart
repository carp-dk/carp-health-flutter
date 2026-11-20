/// The state of the measurement form and its plugin calls, `writeHealthData` and `writeHealthDataUUID`.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import '../common/record_options.dart';
import '../common/write_form_controller.dart';
import '../common/write_outcome.dart';
import 'measurement_rules.dart';

/// The two methods that write one value of a type: the same arguments, different results.
enum MeasurementWriteMethod {
  /// `writeHealthData`: returns whether the value was saved.
  writeHealthData('Returns true when saved.'),

  /// `writeHealthDataUUID`: returns the new record's UUID (an empty string when nothing was saved), which
  /// `getHealthDataByUUID` and `deleteByUUID` take.
  writeHealthDataUUID("Returns the record's UUID, to look it up or delete it.");

  const MeasurementWriteMethod(this.returns);

  /// What the method returns, in a few words.
  final String returns;
}

/// One value of any type that `writeHealthData` writes ([types], from `TypeCatalog.writableTypes`), its
/// unit (iOS), when it was measured, how it was recorded and, on Android, a client record id.
class MeasurementController extends WriteFormController with RecordingMethodOption, ClientRecordIdOption {
  /// Creates the form's state, writing through [health] one of [types]: a heart rate over the 20 minutes
  /// up to [now] at first.
  MeasurementController(super.health, {required this.capabilities, required List<HealthDataType> types, DateTime? now})
    : types = List.unmodifiable(types) {
    final current = now ?? DateTime.now();
    _end = DateTime(current.year, current.month, current.day, current.hour, current.minute);
    _start = _end.subtract(MeasurementRules.defaultSpan);
    if (!types.contains(_type) && types.isNotEmpty) _type = types.first;
    _resetValue();
  }

  @override
  final PlatformCapabilities capabilities;

  /// The types offered: those `writeHealthData` writes on this device.
  final List<HealthDataType> types;

  MeasurementWriteMethod _method = MeasurementWriteMethod.writeHealthDataUUID;
  HealthDataType _type = HealthDataType.HEART_RATE;
  HealthDataUnit _unit = HealthDataUnit.BEATS_PER_MINUTE;
  late DateTime _start, _end;

  /// The value (`value`), as typed.
  final TextEditingController value = TextEditingController();

  /// The platform whose rules apply; Health Connect's where the plugin has no platform (desktop tests).
  HealthPlatformType get platform => capabilities.platform ?? HealthPlatformType.googleHealthConnect;

  /// Whether the app runs on iOS, where the plugin takes a unit.
  bool get isIOS => capabilities.isIOS;

  /// Whether the app runs on Android, where Health Connect decides the unit.
  bool get isAndroid => capabilities.isAndroid;

  /// The write method the form calls.
  MeasurementWriteMethod get method => _method;
  set method(MeasurementWriteMethod value) => update(() => _method = value);

  @override
  HealthDataType get type => _type;

  /// Picks [value] as the type to write, with its sample value and default unit, and a duration where
  /// the platform needs one.
  set type(HealthDataType value) => update(() {
    _type = value;
    _resetValue();
    if (needsDuration && !_end.isAfter(_start)) _start = _end.subtract(MeasurementRules.defaultSpan);
  });

  /// The unit of the value (`unit`); the plugin uses it on iOS only.
  HealthDataUnit get unit => _unit;
  set unit(HealthDataUnit value) => update(() => _unit = value);

  /// The units HealthKit converts [type] from, its default first.
  List<HealthDataUnit> get units => MeasurementRules.unitsFor(_type);

  /// The unit the value is stored in: the chosen one on iOS, the type's own on Android, where Health
  /// Connect decides it and the plugin ignores `unit`.
  HealthDataUnit get effectiveUnit => capabilities.isIOS ? _unit : _type.defaultUnit;

  /// The start of the measurement (`startTime`).
  DateTime get start => _start;

  /// The end of the measurement (`endTime`): the start for an instant.
  DateTime get end => _end;

  /// Sets the start and end together, as the time fields change them.
  void setSpan(DateTime start, DateTime end) => update(() {
    _start = start;
    _end = end;
  });

  /// Whether the plugin ignores the value of [type] (sleep, headaches, mindfulness).
  bool get ignoresValue => MeasurementRules.ignoresValue(_type);

  /// Whether the platform needs the measurement to end after it starts.
  bool get needsDuration => MeasurementRules.needsDuration(_type, platform);

  /// Whether the value is a fraction, as HealthKit's percentages are.
  bool get isFraction => MeasurementRules.isFraction(effectiveUnit, platform);

  /// The value as a number, or null while the field holds none.
  num? get number => NumberField.parse(value.text);

  /// Tells the form that the value's text changed, so whatever shows it follows.
  void valueEdited() => update(() {});

  @override
  String get description {
    if (ignoresValue) return formatDuration(_end.difference(_start));
    final number = this.number;
    return number == null ? _type.label : formatNumericValue(number, effectiveUnit, type: _type, platform: platform);
  }

  @override
  Future<WriteOutcome> performWrite() async {
    final number = ignoresValue
        ? 0.0
        : (this.number?.toDouble() ?? (throw ArgumentError.value(value.text, 'value', 'Enter a number')));
    final id = clientRecordIdValue;
    // The unit is iOS only: on Android the plugin ignores it.
    final unit = capabilities.isIOS ? _unit : null;
    switch (_method) {
      case MeasurementWriteMethod.writeHealthData:
        final saved = await health.writeHealthData(
          value: number,
          unit: unit,
          type: _type,
          startTime: _start,
          endTime: _end,
          recordingMethod: recordingMethod,
          clientRecordId: id,
          clientRecordVersion: clientRecordVersionValue,
        );
        return WriteOutcome.fromBool(_method.name, _type, description, saved, clientRecordId: id);
      case MeasurementWriteMethod.writeHealthDataUUID:
        final uuid = await health.writeHealthDataUUID(
          value: number,
          unit: unit,
          type: _type,
          startTime: _start,
          endTime: _end,
          recordingMethod: recordingMethod,
          clientRecordId: id,
          clientRecordVersion: clientRecordVersionValue,
        );
        return WriteOutcome.fromUuid(_method.name, _type, description, uuid, clientRecordId: id);
    }
  }

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  /// Puts the sample value and the default unit of [type] in the form.
  void _resetValue() {
    _unit = units.first;
    value.text = ignoresValue ? '' : plainNumber(MeasurementRules.sampleValue(_type, platform));
  }

  /// [number] as it is typed in a field: without grouping, and without a trailing ".0".
  static String plainNumber(double number) =>
      number == number.roundToDouble() ? number.toInt().toString() : number.toString();
}
