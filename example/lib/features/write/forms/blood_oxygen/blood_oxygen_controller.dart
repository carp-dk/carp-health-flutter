/// The state of the blood oxygen form and its plugin call, `Health.writeBloodOxygen`.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import '../common/record_options.dart';
import '../common/write_form_controller.dart';
import '../common/write_outcome.dart';

/// An oxygen saturation to write, in percent, with the time it was measured and how it was recorded.
///
/// The two platforms count the saturation differently: Health Connect from 0 to 100 %, HealthKit as a
/// fraction (its percent unit: 0.98 is 98 %), and `writeBloodOxygen` passes the value on as it is. The
/// form takes a percentage on both and sends the fraction on iOS ([saturationArgument]), so both store
/// the same saturation.
class BloodOxygenController extends WriteFormController with RecordingMethodOption {
  /// Creates the form's state, writing through [health]; the saturation is measured at [now] by default.
  BloodOxygenController(super.health, {required this.capabilities, DateTime? now})
    : _measuredAt = now ?? DateTime.now();

  @override
  final PlatformCapabilities capabilities;

  /// The saturation in percent, such as 98.
  final TextEditingController saturation = TextEditingController(text: '98');

  DateTime _measuredAt;

  /// When the saturation was measured: the write's `startTime`, which `endTime` defaults to.
  DateTime get measuredAt => _measuredAt;

  set measuredAt(DateTime value) => update(() => _measuredAt = value);

  @override
  HealthDataType get type => HealthDataType.BLOOD_OXYGEN;

  @override
  String get description {
    final percent = NumberField.parse(saturation.text);
    return percent == null ? 'Oxygen saturation' : '${formatNumber(percent, maxDecimals: 1)}%';
  }

  /// The `saturation` argument for [percent]: the percentage on Android, the fraction on iOS.
  double saturationArgument(num percent) => capabilities.isIOS ? percent / 100 : percent.toDouble();

  @override
  Future<WriteOutcome> performWrite() async {
    final percent =
        NumberField.parse(saturation.text) ??
        (throw ArgumentError.value(saturation.text, 'saturation', 'Enter a percentage'));
    final saved = await health.writeBloodOxygen(
      saturation: saturationArgument(percent),
      startTime: measuredAt,
      recordingMethod: recordingMethod,
    );
    return WriteOutcome.fromBool('writeBloodOxygen', type, description, saved);
  }

  @override
  void dispose() {
    saturation.dispose();
    super.dispose();
  }
}
