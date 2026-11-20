/// The state of the Activity intensity form and its plugin call, `Health.writeActivityIntensity` (Android).
library;

import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/forms/common/record_options.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';
import 'package:health_example/features/write/forms/form_kit/feature_gate.dart';
import 'package:health_example/features/write/forms/form_kit/time_span_option.dart';
import 'package:health_example/features/write/forms/form_kit/write_availability.dart';
import 'package:health_example/features/write/write_recipe.dart';

import 'intensity_levels.dart';

/// A period of activity to write: how intense it was, when, how it was recorded and, optionally, a client
/// record id.
///
/// `writeActivityIntensity` saves a Health Connect activity intensity record, from which Health Connect
/// counts activity minutes. HealthKit has no such type: on iOS the plugin throws an `UnsupportedError`.
/// Health Connect added activity intensity in a later version, so the write also needs
/// `isActivityIntensityAvailable` ([PlatformCapabilities.activityIntensityAvailable]); without it the
/// plugin throws a `HealthException` with `HealthErrorCode.notSupported`.
class ActivityIntensityController extends WriteFormController
    with RecordingMethodOption, ClientRecordIdOption, TimeSpanOption, WriteAvailability {
  /// Creates the form's state: 30 minutes of moderate activity that end now (or at [now]), written
  /// through [health] on the platform [capabilities] describe.
  ActivityIntensityController(super.health, {required this.capabilities, DateTime? now}) {
    initSpan(const Duration(minutes: 30), end: now);
  }

  /// The levels the form offers: `unknown` throws an `ArgumentError`.
  static const List<ActivityIntensityLevel> levels = [ActivityIntensityLevel.moderate, ActivityIntensityLevel.vigorous];

  @override
  final PlatformCapabilities capabilities;

  ActivityIntensityLevel _level = ActivityIntensityLevel.moderate;

  /// How intense the activity was (`intensityLevel`).
  ActivityIntensityLevel get level => _level;
  set level(ActivityIntensityLevel value) => update(() => _level = value);

  @override
  HealthDataType get type => HealthDataType.ACTIVITY_INTENSITY;

  @override
  String? get unavailableReason => capabilities.isAndroid
      ? missingFeatureReason(RecipeFeature.activityIntensity, capabilities)
      : 'Android only: HealthKit has no activity intensity.';

  @override
  String get description => '${_level.label} · ${formatDuration(duration)}';

  @override
  Future<WriteOutcome> performWrite() async {
    checkAvailable();
    final clientRecordId = clientRecordIdValue;
    final saved = await health.writeActivityIntensity(
      intensityLevel: _level,
      startTime: start,
      endTime: end,
      recordingMethod: recordingMethod,
      clientRecordId: clientRecordId,
      clientRecordVersion: clientRecordVersionValue,
    );
    return WriteOutcome.fromBool('writeActivityIntensity', type, description, saved, clientRecordId: clientRecordId);
  }
}
