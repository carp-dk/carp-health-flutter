/// The state of the Mindfulness form and its plugin call, `Health.writeMindfulnessSession`.
library;

import 'package:flutter/widgets.dart';
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

import 'mindfulness_session_types.dart';

/// A mindfulness session to write: its time, how it was recorded, and its type, title and notes, which
/// only Health Connect stores.
///
/// `writeMindfulnessSession` saves a Health Connect mindfulness session on Android and a HealthKit mindful
/// session on iOS, which has no type, title or notes. Reads return either as a `MINDFULNESS` data point
/// whose value is its minutes, without the type, title and notes. Health Connect added mindfulness
/// sessions after its first release, so on Android the write needs `isMindfulnessSessionAvailable`
/// ([PlatformCapabilities.mindfulnessAvailable]); without it the plugin throws a `HealthException` with
/// `HealthErrorCode.notSupported`.
class MindfulnessController extends WriteFormController with RecordingMethodOption, TimeSpanOption, WriteAvailability {
  /// Creates the form's state: a 10-minute breathing session that ends now (or at [now]), written through
  /// [health] on the platform [capabilities] describe.
  MindfulnessController(super.health, {required this.capabilities, DateTime? now}) {
    initSpan(const Duration(minutes: 10), end: now);
  }

  @override
  final PlatformCapabilities capabilities;

  MindfulnessSessionType _sessionType = MindfulnessSessionType.BREATHING;

  /// The session's title (`title`), which only Health Connect stores; empty for none.
  final TextEditingController title = TextEditingController(text: 'Morning practice');

  /// Notes about the session (`notes`), which only Health Connect stores; empty for none.
  final TextEditingController notes = TextEditingController();

  /// The type of the session (`sessionType`), which only Health Connect stores.
  MindfulnessSessionType get sessionType => _sessionType;
  set sessionType(MindfulnessSessionType value) => update(() => _sessionType = value);

  /// Whether the platform stores the session's type, title and notes: only Health Connect does.
  bool get storesDetails => capabilities.isAndroid;

  @override
  HealthDataType get type => HealthDataType.MINDFULNESS;

  @override
  String? get unavailableReason => missingFeatureReason(RecipeFeature.mindfulness, capabilities);

  @override
  String get description => '${storesDetails ? _sessionType.label : 'Mindful session'} · ${formatDuration(duration)}';

  @override
  Future<WriteOutcome> performWrite() async {
    checkAvailable();
    final saved = await health.writeMindfulnessSession(
      startTime: start,
      endTime: end,
      // HealthKit's mindful sessions have no type, title or notes: the form sends them only where they are
      // stored, as it shows them only there.
      sessionType: storesDetails ? _sessionType : MindfulnessSessionType.UNKNOWN,
      title: storesDetails ? _text(title) : null,
      notes: storesDetails ? _text(notes) : null,
      recordingMethod: recordingMethod,
    );
    return WriteOutcome.fromBool('writeMindfulnessSession', type, description, saved);
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  static String? _text(TextEditingController field) => field.text.trim().isEmpty ? null : field.text.trim();
}
