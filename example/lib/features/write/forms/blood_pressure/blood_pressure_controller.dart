/// The state of the blood pressure form and its plugin call, `Health.writeBloodPressure`.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import '../common/record_options.dart';
import '../common/write_form_controller.dart';
import '../common/write_outcome.dart';

/// A blood pressure reading to write: systolic and diastolic pressure in mmHg, when it was measured, how
/// it was recorded and, on Android, a client record id.
///
/// `writeBloodPressure` saves one reading as a HealthKit blood pressure correlation of a systolic and a
/// diastolic sample, or as one Health Connect blood pressure record. Reads return it as a
/// `BLOOD_PRESSURE_SYSTOLIC` and a `BLOOD_PRESSURE_DIASTOLIC` data point.
class BloodPressureController extends WriteFormController with RecordingMethodOption, ClientRecordIdOption {
  /// Creates the form's state, writing through [health]; the reading is measured at [now] by default.
  BloodPressureController(super.health, {required this.capabilities, DateTime? now})
    : _measuredAt = now ?? DateTime.now();

  @override
  final PlatformCapabilities capabilities;

  /// The systolic pressure in mmHg (a whole number).
  final TextEditingController systolic = TextEditingController(text: '120');

  /// The diastolic pressure in mmHg (a whole number).
  final TextEditingController diastolic = TextEditingController(text: '80');

  DateTime _measuredAt;

  /// When the reading was taken: the write's `startTime`, which `endTime` defaults to.
  DateTime get measuredAt => _measuredAt;

  set measuredAt(DateTime value) => update(() => _measuredAt = value);

  @override
  HealthDataType get type => HealthDataType.BLOOD_PRESSURE_SYSTOLIC;

  /// HealthKit authorizes the two samples of the correlation one by one, so both types need write access.
  @override
  List<HealthDataType> get accessTypes => const [
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  ];

  @override
  String get description => '${systolic.text.trim()}/${diastolic.text.trim()} mmHg';

  @override
  Future<WriteOutcome> performWrite() async {
    final clientRecordId = clientRecordIdValue;
    final saved = await health.writeBloodPressure(
      systolic: _pressure(systolic, 'systolic'),
      diastolic: _pressure(diastolic, 'diastolic'),
      startTime: measuredAt,
      clientRecordId: clientRecordId,
      clientRecordVersion: clientRecordVersionValue,
      recordingMethod: recordingMethod,
    );
    return WriteOutcome.fromBool('writeBloodPressure', type, description, saved, clientRecordId: clientRecordId);
  }

  @override
  void dispose() {
    systolic.dispose();
    diastolic.dispose();
    super.dispose();
  }

  /// The whole number in [field]; the form's validation runs first, so a missing one is a bug.
  static int _pressure(TextEditingController field, String name) =>
      NumberField.parse(field.text)?.round() ?? (throw ArgumentError.value(field.text, name, 'Enter a number'));
}
