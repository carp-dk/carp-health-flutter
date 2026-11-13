part of '../../health.dart';

/// The stroke style of a [SwimmingLap].
///
/// iOS stores it as the stroke style of the lap in HealthKit (`HKMetadataKeySwimmingStrokeStyle`), and Android as a
/// Health Connect exercise segment over the lap. Each platform reads back the style it stored, except the styles it
/// has no value for: [kickboard] and [other] say what those read back as.
enum SwimmingStrokeStyle {
  /// The style is not known. iOS stores HealthKit's `unknown`, and reads it for a lap without a stroke style. Android
  /// stores no segment for the lap, and reads it for a lap that starts in no segment of a stroke style.
  unknown,

  /// More than one style in the lap: HealthKit's `mixed` and Health Connect's `SWIMMING_MIXED`.
  mixed,

  /// Freestyle: HealthKit's `freestyle` and Health Connect's `SWIMMING_FREESTYLE`.
  freestyle,

  /// Backstroke: HealthKit's `backstroke` and Health Connect's `SWIMMING_BACKSTROKE`.
  backstroke,

  /// Breaststroke: HealthKit's `breaststroke` and Health Connect's `SWIMMING_BREASTSTROKE`.
  breaststroke,

  /// Butterfly: HealthKit's `butterfly` and Health Connect's `SWIMMING_BUTTERFLY`.
  butterfly,

  /// Kicking with a kickboard: HealthKit's `kickboard`, from iOS 16; earlier iOS versions store and read back
  /// [unknown]. Health Connect has no such style: Android stores `SWIMMING_OTHER`, which reads back as [other].
  kickboard,

  /// A style the others do not describe: Health Connect's `SWIMMING_OTHER`. HealthKit has no such style: iOS stores
  /// `unknown`, which reads back as [unknown].
  other,
}

/// A lap of a swimming workout from [startTime] to [endTime], such as a length of the pool, in [strokeStyle].
///
/// iOS stores a lap as a lap event of the workout in HealthKit (an `HKWorkoutEvent` of type `lap`) with its stroke
/// style, and reads also list it in [WorkoutHealthValue.workoutEvents], as a [WorkoutEventType.lap] without a stroke
/// style. Android stores it as a Health Connect `ExerciseLap` with the [SwimmingDetails.poolLength] as its length, and
/// its stroke style as an `ExerciseSegment` over the lap. A lap reads back with the times it was written with and the
/// stroke style that [SwimmingStrokeStyle] says.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class SwimmingLap {
  /// The start of the lap. It must be before [endTime] in a write. Laps that an Apple Watch recorded before watchOS 4
  /// have no duration: they start at their end.
  final DateTime startTime;

  /// The end of the lap.
  final DateTime endTime;

  /// The stroke style of the lap, [SwimmingStrokeStyle.unknown] when it is not known.
  final SwimmingStrokeStyle strokeStyle;

  /// Create a lap from [startTime] to [endTime] in [strokeStyle].
  const SwimmingLap({required this.startTime, required this.endTime, this.strokeStyle = SwimmingStrokeStyle.unknown});

  /// Create a [SwimmingLap] from a lap in the `swimming` map the native side sends. A stroke style this version of the
  /// plugin does not know is [SwimmingStrokeStyle.unknown].
  factory SwimmingLap.fromHealthDataPoint(Map<String, dynamic> data) => SwimmingLap(
    startTime: _dateTimeFrom(data['startTime']),
    endTime: _dateTimeFrom(data['endTime']),
    strokeStyle: SwimmingStrokeStyle.values.asNameMap()[data['strokeStyle']] ?? SwimmingStrokeStyle.unknown,
  );

  static DateTime _dateTimeFrom(dynamic milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch((milliseconds as num).toInt(), isUtc: true).toLocal();

  /// Create a [SwimmingLap] from JSON.
  factory SwimmingLap.fromJson(Map<String, dynamic> json) => _$SwimmingLapFromJson(json);

  /// This lap as JSON.
  Map<String, dynamic> toJson() => _$SwimmingLapToJson(this);

  @override
  bool operator ==(Object other) =>
      other is SwimmingLap &&
      startTime == other.startTime &&
      endTime == other.endTime &&
      strokeStyle == other.strokeStyle;

  @override
  int get hashCode => Object.hash(startTime, endTime, strokeStyle);

  @override
  String toString() => '$runtimeType - startTime: $startTime, endTime: $endTime, strokeStyle: ${strokeStyle.name}';
}

/// The details of a swimming workout: the length of the pool and the laps.
///
/// Write them with the `swimming` argument of [Health.writeWorkoutData] and [Health.writeWorkoutDataUUID], for a
/// [HealthWorkoutActivityType.SWIMMING_POOL] or [HealthWorkoutActivityType.SWIMMING_OPEN_WATER] workout or, on iOS, a
/// [HealthWorkoutActivityType.SWIMMING] one. Read them in [WorkoutHealthValue.swimming], also for the swims that other
/// apps and watches wrote.
///
/// iOS stores the [poolLength] in HealthKit as the lap length of the workout (`HKMetadataKeyLapLength`), with a pool
/// location (`HKMetadataKeySwimmingLocationType`), and the [laps] as lap events of the workout.
///
/// Android stores the [laps] as Health Connect `ExerciseLap`s, each with the [poolLength] as its length, as Health
/// Connect has no pool length of its own, and their stroke styles as `ExerciseSegment`s over them.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class SwimmingDetails {
  /// The length of the pool in meters: more than 0 and at most 1000, and only for a
  /// [HealthWorkoutActivityType.SWIMMING_POOL] workout in a write. Null when it is not known, and for an open water
  /// swim.
  ///
  /// iOS reads the lap length of a HealthKit swim in meters, also when the pool was measured in yards (25 yards read
  /// as 22.86 meters). A SWIMMING_POOL workout written without a pool length is saved as a swim without a location,
  /// as HealthKit takes no pool swim without a lap length, and reads back as [HealthWorkoutActivityType.SWIMMING].
  ///
  /// Android reads the length that all laps of a pool swim share, null when they differ or have none. A pool length
  /// written without laps is not stored.
  final double? poolLength;

  /// The laps, sorted by start time. In a write they must be inside the workout and must not overlap.
  final List<SwimmingLap> laps;

  /// Create the details of a swim: the [poolLength] in meters of a pool swim, and the [laps].
  const SwimmingDetails({this.poolLength, this.laps = const []});

  /// Create [SwimmingDetails] from the `swimming` map the native side sends.
  factory SwimmingDetails.fromHealthDataPoint(Map<String, dynamic> data) => SwimmingDetails(
    poolLength: (data['poolLength'] as num?)?.toDouble(),
    laps: [
      for (final lap in data['laps'] as List<dynamic>? ?? const <dynamic>[])
        SwimmingLap.fromHealthDataPoint(Map<String, dynamic>.from(lap as Map)),
    ],
  );

  /// The details in [data], the `swimming` map of a workout that the native side sends, or null when it sends none
  /// or one with neither a pool length nor laps: [WorkoutHealthValue.swimming] is null when nothing is known.
  static SwimmingDetails? _ofWorkout(Object? data) {
    if (data == null) return null;
    final details = SwimmingDetails.fromHealthDataPoint(Map<String, dynamic>.from(data as Map));
    return details.poolLength == null && details.laps.isEmpty ? null : details;
  }

  /// Create [SwimmingDetails] from JSON.
  factory SwimmingDetails.fromJson(Map<String, dynamic> json) => _$SwimmingDetailsFromJson(json);

  /// These details as JSON.
  Map<String, dynamic> toJson() => _$SwimmingDetailsToJson(this);

  @override
  bool operator ==(Object other) =>
      other is SwimmingDetails && poolLength == other.poolLength && listEquals(laps, other.laps);

  @override
  int get hashCode => Object.hash(poolLength, Object.hashAll(laps));

  @override
  String toString() => '$runtimeType - poolLength: $poolLength, laps: ${laps.length}';
}
