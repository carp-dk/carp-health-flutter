/// The state of the Insulin delivery form and its plugin call, `Health.writeInsulinDelivery` (iOS).
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';
import 'package:health_example/features/write/forms/form_kit/time_span_option.dart';
import 'package:health_example/features/write/forms/form_kit/write_availability.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

/// An insulin delivery to write: the units, why they were delivered (basal or bolus) and when.
///
/// `writeInsulinDelivery` saves a HealthKit insulin delivery sample in international units (IU) with the
/// delivery reason (`HKMetadataKeyInsulinDeliveryReason`) that HealthKit requires, which is why
/// `writeHealthData` refuses this type on iOS. Health Connect has no insulin type: on Android the plugin
/// throws an `UnsupportedError`, so the form offers the write on iOS only.
class InsulinDeliveryController extends WriteFormController with TimeSpanOption, WriteAvailability {
  /// Creates the form's state: a 5 IU bolus delivered now (or at [now]), written through [health] on the
  /// platform [capabilities] describe.
  InsulinDeliveryController(super.health, {required this.capabilities, DateTime? now}) {
    initSpan(Duration.zero, end: now);
  }

  @override
  final PlatformCapabilities capabilities;

  /// The insulin units delivered (`units`).
  final TextEditingController units = TextEditingController(text: '5');

  InsulinDeliveryReason _reason = InsulinDeliveryReason.BOLUS;

  /// Why the insulin was delivered (`reason`): basal or bolus, as `NOT_SET` throws an `ArgumentError`.
  InsulinDeliveryReason get reason => _reason;
  set reason(InsulinDeliveryReason value) => update(() => _reason = value);

  @override
  HealthDataType get type => HealthDataType.INSULIN_DELIVERY;

  @override
  String? get unavailableReason => capabilities.isIOS ? null : 'iOS only: Health Connect has no insulin type.';

  @override
  String get description {
    final amount = NumberField.parse(units.text);
    return '${amount == null ? '?' : formatNumber(amount)} IU ${_reason.name.toLowerCase()}';
  }

  /// Notifies the form that the units changed, so the description follows them.
  void unitsChanged() => update(() {});

  @override
  Future<WriteOutcome> performWrite() async {
    checkAvailable();
    // The form validates the field first, so an empty one only reaches here when called directly.
    final amount = NumberField.parse(units.text)?.toDouble() ?? (throw ArgumentError.value(units.text, 'units'));
    final saved = await health.writeInsulinDelivery(amount, _reason, start, end);
    return WriteOutcome.fromBool('writeInsulinDelivery', type, description, saved);
  }

  @override
  void dispose() {
    units.dispose();
    super.dispose();
  }
}
