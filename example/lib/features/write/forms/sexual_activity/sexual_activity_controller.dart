/// The state of the Sexual activity form and its plugin call, `Health.writeSexualActivity`.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/forms/common/record_options.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';
import 'package:health_example/features/write/forms/form_kit/choice_tiles.dart';
import 'package:health_example/features/write/forms/form_kit/time_span_option.dart';

/// A label, icon and choice tile for each [SexualActivityProtection].
extension SexualActivityProtectionVisuals on SexualActivityProtection {
  /// Human-readable label for this protection status.
  String get label => switch (this) {
    SexualActivityProtection.protected => 'Protected',
    SexualActivityProtection.unprotected => 'Unprotected',
    SexualActivityProtection.unknown => 'Unspecified',
  };

  /// Icon representing this protection status.
  IconData get icon => switch (this) {
    SexualActivityProtection.protected => Icons.verified_user_outlined,
    SexualActivityProtection.unprotected => Icons.gpp_maybe_outlined,
    SexualActivityProtection.unknown => Icons.help_outline,
  };

  /// Choice tile for the form's protection picker.
  ChoiceTile<SexualActivityProtection> get tile => ChoiceTile(value: this, label: label, icon: icon);
}

/// A sexual activity entry to write: protection status, time, recording method and, on Android,
/// a client record id.
class SexualActivityController extends WriteFormController with RecordingMethodOption, ClientRecordIdOption {
  /// Creates the form's state: protected activity at [now] (or the current minute), written through
  /// [health] on the platform [capabilities] describe.
  SexualActivityController(super.health, {required this.capabilities, DateTime? now})
    : _time = TimeSpanOption.wholeMinute(now ?? DateTime.now());

  @override
  final PlatformCapabilities capabilities;

  SexualActivityProtection _protectionUsed = SexualActivityProtection.protected;
  DateTime _time;

  /// Whether protection was used (`protectionUsed`).
  SexualActivityProtection get protectionUsed => _protectionUsed;
  set protectionUsed(SexualActivityProtection value) => update(() => _protectionUsed = value);

  /// When the activity occurred (`startTime`; `endTime` defaults to `startTime`).
  DateTime get time => _time;
  set time(DateTime value) => update(() => _time = value);

  @override
  HealthDataType get type => HealthDataType.SEXUAL_ACTIVITY;

  @override
  String get description => _protectionUsed.label;

  @override
  Future<WriteOutcome> performWrite() async {
    final clientRecordId = clientRecordIdValue;
    final saved = await health.writeSexualActivity(
      protectionUsed: _protectionUsed,
      startTime: _time,
      recordingMethod: recordingMethod,
      clientRecordId: clientRecordId,
      clientRecordVersion: clientRecordVersionValue,
    );
    return WriteOutcome.fromBool('writeSexualActivity', type, description, saved, clientRecordId: clientRecordId);
  }
}
