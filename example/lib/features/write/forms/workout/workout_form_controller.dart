/// The state of the workout form and its plugin calls, `writeWorkoutData` and `writeWorkoutDataUUID`.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/forms/common/record_options.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'swim_form_state.dart';
import 'workout_activities.dart';
import 'workout_metadata_fields.dart';

/// The two workout write methods: the same arguments, different results.
enum WorkoutWriteMethod {
  /// `writeWorkoutData`: returns whether the workout was saved.
  writeWorkoutData('Returns true when saved.'),

  /// `writeWorkoutDataUUID`: returns the new workout's UUID (an empty string when nothing was saved), which
  /// `getHealthDataByUUID`, `deleteByUUID` and `finishWorkoutRoute` take.
  writeWorkoutDataUUID("Returns the workout's UUID, to read, delete or attach a route to it.");

  const WorkoutWriteMethod(this.returns);

  /// What the method returns, in a sentence.
  final String returns;
}

/// The workout form's input and its write: the activity, times and totals, the swimming details of a swim,
/// the Health Connect title and client record id (Android) and the HealthKit metadata (iOS).
///
/// Arguments that only one platform stores are sent only there. The plugin ignores them on the other
/// platform anyway, but still checks them everywhere (an id needs its version, swimming details need a swim).
class WorkoutFormController extends WriteFormController
    with RecordingMethodOption, ClientRecordIdOption, SwimFormState, WorkoutMetadataFields {
  /// Creates the form's state with a 30-minute run that ends now (or at [now]), written through [health].
  WorkoutFormController(super.health, {required this.capabilities, DateTime? now}) {
    final current = now ?? DateTime.now();
    _end = DateTime(current.year, current.month, current.day, current.hour, current.minute);
    _start = _end.subtract(const Duration(minutes: 30));
  }

  @override
  final PlatformCapabilities capabilities;

  WorkoutWriteMethod _method = WorkoutWriteMethod.writeWorkoutDataUUID;
  HealthWorkoutActivityType _activity = HealthWorkoutActivityType.RUNNING;
  late DateTime _start, _end;

  /// The total distance in meters (`totalDistance`); empty for none.
  final TextEditingController distance = TextEditingController(text: '5000');

  /// The total energy burned in kilocalories (`totalEnergyBurned`); empty for none.
  final TextEditingController energy = TextEditingController(text: '300');

  /// The Health Connect title (`title`); empty for the plugin's default, the activity's name.
  final TextEditingController title = TextEditingController();

  /// The write method the form calls.
  WorkoutWriteMethod get method => _method;
  set method(WorkoutWriteMethod value) => update(() => _method = value);

  /// The activity (`activityType`).
  HealthWorkoutActivityType get activity => _activity;
  set activity(HealthWorkoutActivityType value) => update(() => _activity = value);

  /// The activities this platform writes, sorted by name; the plugin throws `notSupported` for others.
  List<HealthWorkoutActivityType> get activities =>
      WorkoutActivities.on(capabilities.platform ?? HealthPlatformType.googleHealthConnect);

  /// The start of the workout.
  DateTime get start => _start;

  /// The end of the workout.
  DateTime get end => _end;

  /// Sets the start and end of the workout; the laps of a swim move with the start.
  void setTimes(DateTime start, DateTime end) => update(() {
    _start = start;
    _end = end;
  });

  @override
  Duration get workoutDuration => _end.difference(_start);

  @override
  DateTime get workoutStart => _start;

  @override
  bool get isSwim => WorkoutActivities.isSwim(_activity);

  @override
  bool get isPoolSwim => _activity == HealthWorkoutActivityType.SWIMMING_POOL;

  @override
  HealthDataType get type => HealthDataType.WORKOUT;

  /// On Android the distance and energy are records of their own, which need their own write access.
  @override
  List<HealthDataType> get accessTypes => [
    HealthDataType.WORKOUT,
    if (capabilities.isAndroid && _number(distance) != null) HealthDataType.DISTANCE_DELTA,
    if (capabilities.isAndroid && _number(energy) != null) HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  @override
  String get description => [
    WorkoutActivities.label(_activity),
    formatDuration(workoutDuration),
    if (_number(distance) case final meters?) '${formatNumber(meters)} m',
    if (_number(energy) case final kcal?) '${formatNumber(kcal)} kcal',
    if (isSwim && laps.isNotEmpty) '${laps.length} laps',
  ].join(' · ');

  /// Sets the total distance to the distance the laps cover in the pool ([lapDistance]).
  void useLapDistance() {
    if (lapDistance case final meters?) update(() => distance.text = '${meters.round()}');
  }

  /// Notifies the form that a text field changed, so the preview and the access types follow it.
  void textChanged() => update(() {});

  @override
  Future<WriteOutcome> performWrite() async {
    final description = this.description;
    final clientRecordId = clientRecordIdValue;
    // Each platform ignores the other's arguments; sending only its own keeps the call honest.
    final title = capabilities.isAndroid ? _text(this.title) : null;
    final metadata = capabilities.isIOS ? this.metadata : null;
    final strokes = capabilities.isIOS && isSwim ? _number(strokeCount)?.toInt() : null;
    switch (_method) {
      case WorkoutWriteMethod.writeWorkoutData:
        final saved = await health.writeWorkoutData(
          activityType: _activity,
          start: _start,
          end: _end,
          totalDistance: _number(distance)?.round(),
          totalEnergyBurned: _number(energy)?.round(),
          title: title,
          metadata: metadata,
          recordingMethod: recordingMethod,
          clientRecordId: clientRecordId,
          clientRecordVersion: clientRecordVersionValue,
          swimming: swimmingDetails,
          totalSwimmingStrokeCount: strokes,
        );
        return WriteOutcome.fromBool(_method.name, type, description, saved, clientRecordId: clientRecordId);
      case WorkoutWriteMethod.writeWorkoutDataUUID:
        final uuid = await health.writeWorkoutDataUUID(
          activityType: _activity,
          start: _start,
          end: _end,
          totalDistance: _number(distance)?.round(),
          totalEnergyBurned: _number(energy)?.round(),
          title: title,
          metadata: metadata,
          recordingMethod: recordingMethod,
          clientRecordId: clientRecordId,
          clientRecordVersion: clientRecordVersionValue,
          swimming: swimmingDetails,
          totalSwimmingStrokeCount: strokes,
        );
        return WriteOutcome.fromUuid(_method.name, type, description, uuid, clientRecordId: clientRecordId);
    }
  }

  @override
  void dispose() {
    distance.dispose();
    energy.dispose();
    title.dispose();
    super.dispose();
  }

  static String? _text(TextEditingController field) => field.text.trim().isEmpty ? null : field.text.trim();

  static num? _number(TextEditingController field) => NumberField.parse(field.text);
}
