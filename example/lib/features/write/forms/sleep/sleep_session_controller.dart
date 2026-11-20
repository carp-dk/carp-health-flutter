/// The state of the Sleep session form and its plugin call, `Health.writeSleepSession`.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/forms/common/record_options.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';
import 'package:health_example/features/write/forms/form_kit/time_span_option.dart';
import 'package:health_example/features/write/forms/form_kit/write_availability.dart';

/// One stage of the session being edited: its type and how long it lasts. The form lays the stages out
/// one after another from the session's start.
@immutable
class SleepStageDraft {
  /// Creates a stage of [type] that lasts [duration].
  const SleepStageDraft(this.type, this.duration);

  /// The sleep type of the stage, such as `SLEEP_DEEP`.
  final HealthDataType type;

  /// How long the stage lasts.
  final Duration duration;
}

/// A night (or nap) to write: its start, its stages, how it was recorded, and a title and notes, which
/// only Health Connect stores.
///
/// `writeSleepSession` saves one Health Connect sleep session with its stages on Android. HealthKit has no
/// sessions, so iOS saves in-bed samples for the session and one sleep analysis sample per stage (unknown
/// and out-of-bed stages get none). The plugin checks the stages before anything is written and throws an
/// `ArgumentError` for a stage outside the session or stages that overlap, which the form shows.
class SleepSessionController extends WriteFormController with RecordingMethodOption, WriteAvailability {
  /// Creates the form's state: a short sample night that ends now (or at [now]), written through [health]
  /// on the platform [capabilities] describe.
  SleepSessionController(super.health, {required this.capabilities, DateTime? now}) {
    _start = TimeSpanOption.wholeMinute(now ?? DateTime.now()).subtract(_total);
  }

  /// The stage types `SleepSessionStage` takes, in the order the form offers them.
  static const List<HealthDataType> stageTypes = [
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_UNKNOWN,
  ];

  /// How much one tap of a stage's stepper changes its length, and the shortest and longest stage.
  static const Duration stageStep = Duration(minutes: 5);
  static const Duration minStage = Duration(minutes: 5);
  static const Duration maxStage = Duration(hours: 4);

  @override
  final PlatformCapabilities capabilities;

  late DateTime _start;
  List<SleepStageDraft> _stages = const [
    SleepStageDraft(HealthDataType.SLEEP_LIGHT, Duration(minutes: 30)),
    SleepStageDraft(HealthDataType.SLEEP_DEEP, Duration(minutes: 45)),
    SleepStageDraft(HealthDataType.SLEEP_REM, Duration(minutes: 25)),
    SleepStageDraft(HealthDataType.SLEEP_AWAKE, Duration(minutes: 5)),
  ];

  /// The session's title (`title`), which only Health Connect stores; empty for none.
  final TextEditingController title = TextEditingController(text: 'Sample night');

  /// Notes about the session (`notes`), which only Health Connect stores; empty for none.
  final TextEditingController notes = TextEditingController();

  /// When the session starts (`startTime`).
  DateTime get start => _start;

  /// When the session ends (`endTime`): when its last stage ends.
  DateTime get end => _start.add(_total);

  /// The stages, in order.
  List<SleepStageDraft> get stages => List.unmodifiable(_stages);

  /// Whether the platform stores the session's title and notes: only Health Connect does.
  bool get storesDetails => capabilities.isAndroid;

  Duration get _total => _stages.fold(Duration.zero, (sum, stage) => sum + stage.duration);

  /// Moves the session (and so all its stages) to start at [value].
  void setStart(DateTime value) => update(() => _start = value);

  /// Adds a stage of [type] after the last one.
  void addStage(HealthDataType type) => update(() => _stages = [..._stages, SleepStageDraft(type, minStage * 4)]);

  /// Removes the stage at [index]; the session keeps at least one stage.
  void removeStageAt(int index) {
    if (_stages.length > 1) update(() => _stages = [..._stages]..removeAt(index));
  }

  /// Changes the type of the stage at [index].
  void setStageType(int index, HealthDataType type) => _replace(index, SleepStageDraft(type, _stages[index].duration));

  /// Changes the length of the stage at [index].
  void setStageDuration(int index, Duration duration) =>
      _replace(index, SleepStageDraft(_stages[index].type, duration));

  void _replace(int index, SleepStageDraft stage) => update(() => _stages = [..._stages]..[index] = stage);

  /// The stages as the plugin takes them: one after another from [start].
  List<SleepSessionStage> buildStages() {
    var at = _start;
    return [
      for (final stage in _stages)
        SleepSessionStage(type: stage.type, startTime: at, endTime: at = at.add(stage.duration)),
    ];
  }

  @override
  HealthDataType get type => capabilities.isAndroid ? HealthDataType.SLEEP_SESSION : HealthDataType.SLEEP_IN_BED;

  /// The session's type and the stage types, where this platform has them.
  @override
  List<HealthDataType> get accessTypes => {
    type,
    for (final stage in _stages)
      if (capabilities.supports(stage.type)) stage.type,
  }.toList();

  @override
  String? get unavailableReason => null;

  @override
  String get description => '${formatDuration(_total)} · ${_stages.length} stages';

  @override
  Future<WriteOutcome> performWrite() async {
    checkAvailable();
    final saved = await health.writeSleepSession(
      startTime: start,
      endTime: end,
      stages: buildStages(),
      // HealthKit has no title or notes for sleep: they are sent only where they are stored.
      title: storesDetails ? _text(title) : null,
      notes: storesDetails ? _text(notes) : null,
      recordingMethod: recordingMethod,
    );
    return WriteOutcome.fromBool('writeSleepSession', type, description, saved);
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  static String? _text(TextEditingController field) => field.text.trim().isEmpty ? null : field.text.trim();
}
