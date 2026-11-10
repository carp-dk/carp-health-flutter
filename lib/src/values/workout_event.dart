part of '../../health.dart';

/// The kind of a [WorkoutEvent]: HealthKit's `HKWorkoutEventType`.
enum WorkoutEventType {
  /// The workout was paused.
  pause,

  /// The workout was resumed after a pause.
  resume,

  /// A lap, for example a length of the pool in a pool swim.
  lap,

  /// A point in time the app or the user marked.
  marker,

  /// The workout paused itself, as the user stopped moving.
  motionPaused,

  /// The workout resumed itself, as the user moved again.
  motionResumed,

  /// A part of the workout, for example a set of a swim.
  segment,

  /// The user asked to pause or resume the workout, for example with the
  /// buttons of an Apple Watch in Water Lock.
  pauseOrResumeRequest,

  /// A kind of event HealthKit added after this version of the plugin.
  unknown,
}

/// An event during a workout (iOS only): a pause, a lap, a segment and so on,
/// from [start] to [end]. Laps and segments last; other events end when they
/// start.
///
/// Parameters:
/// * [type] - the kind of event.
/// * [start] - when the event began.
/// * [end] - when the event ended.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class WorkoutEvent extends Serializable {
  WorkoutEventType type;
  DateTime start;
  DateTime end;

  WorkoutEvent({required this.type, required this.start, required this.end});

  /// Create a [WorkoutEvent] from the map the native side sends.
  factory WorkoutEvent.fromHealthDataPoint(Map<String, dynamic> data) => WorkoutEvent(
    type: WorkoutEventType.values.asNameMap()[data['type']] ?? WorkoutEventType.unknown,
    start: _dateTimeFrom(data['start']),
    end: _dateTimeFrom(data['end']),
  );

  static DateTime _dateTimeFrom(dynamic milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch((milliseconds as num).toInt(), isUtc: true).toLocal();

  @override
  Function get fromJsonFunction => _$WorkoutEventFromJson;
  factory WorkoutEvent.fromJson(Map<String, dynamic> json) => FromJsonFactory().fromJson<WorkoutEvent>(json);
  @override
  Map<String, dynamic> toJson() => _$WorkoutEventToJson(this);

  @override
  String toString() => '$runtimeType - type: ${type.name}, start: $start, end: $end';

  @override
  bool operator ==(Object other) =>
      other is WorkoutEvent && type == other.type && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(type, start, end);
}
