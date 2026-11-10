part of '../../health.dart';

/// Part of [Health]: writing a sleep session with its stages, such as a night
/// of sleep.
// ignore: library_private_types_in_public_api
mixin HealthSleepWrites on _HealthSupport {
  /// Write a sleep session from [startTime] to [endTime] with its [stages],
  /// for example a night with its light, deep and REM sleep.
  ///
  /// Returns true if the session was saved, false otherwise.
  ///
  /// Parameters:
  ///  * [startTime] - the start of the session. It must be before [endTime].
  ///  * [endTime] - the end of the session.
  ///  * [stages] - the stages of the session, see [SleepSessionStage]: each
  ///    inside the session, sorted by start time and not overlapping. They
  ///    need not cover the whole session.
  ///  * [title] - **Android only**: the title of the session.
  ///  * [notes] - **Android only**: notes about the session.
  ///  * [recordingMethod] - the recording method of the session, automatic by
  ///    default (on iOS this must be manual or automatic).
  ///
  /// On **Android** this is one Health Connect sleep session with its stages,
  /// [title] and [notes]. Reads return the session as a
  /// [HealthDataType.SLEEP_SESSION] data point and each stage as a data point
  /// of its type; they do not return the title and notes. (A sleep type
  /// written with [Health.writeHealthData] is a session of its own.)
  ///
  /// HealthKit on **iOS** has no sleep sessions. The session is saved as
  /// sleep analysis samples: in-bed samples for the session without its
  /// [HealthDataType.SLEEP_OUT_OF_BED] stages, read as
  /// [HealthDataType.SLEEP_IN_BED], and a sample for each stage of these
  /// types:
  ///  * [HealthDataType.SLEEP_AWAKE] and [HealthDataType.SLEEP_AWAKE_IN_BED]
  ///    as awake, read as [HealthDataType.SLEEP_AWAKE];
  ///  * [HealthDataType.SLEEP_ASLEEP] as asleep (HealthKit's
  ///    `asleepUnspecified`), read as [HealthDataType.SLEEP_ASLEEP];
  ///  * [HealthDataType.SLEEP_LIGHT], [HealthDataType.SLEEP_DEEP] and
  ///    [HealthDataType.SLEEP_REM] as core, deep and REM sleep, read as their
  ///    types. Before iOS 16, which has no such values, they are saved as
  ///    asleep and read as [HealthDataType.SLEEP_ASLEEP].
  ///
  /// [HealthDataType.SLEEP_UNKNOWN] and [HealthDataType.SLEEP_OUT_OF_BED]
  /// stages have no sample of their own: an unknown stage stays time in bed.
  /// The title and notes are not stored. iOS has no
  /// [HealthDataType.SLEEP_SESSION]: read [HealthDataType.SLEEP_IN_BED] for
  /// the time in bed.
  ///
  /// Request write access to a sleep type first, for example
  /// [HealthDataType.SLEEP_ASLEEP]: on each platform all sleep types share
  /// one permission.
  ///
  /// To remove a session, call [Health.delete] over its time range. On
  /// Android, any sleep type deletes the app's whole sleep sessions in the
  /// range, with all their stages. On iOS, which deletes only the samples of
  /// the type given, delete [HealthDataType.SLEEP_IN_BED] and the type each
  /// stage is read as.
  ///
  /// Throws an [ArgumentError], before anything is sent, if [startTime] is not
  /// before [endTime]; if a stage is not of a type listed in
  /// [SleepSessionStage.type], does not start before it ends or is not inside
  /// the session; if the stages are not sorted by start time or overlap; or,
  /// on iOS, if [recordingMethod] is not manual or automatic. Throws an
  /// [UnsupportedError] if Health Connect is not available. On iOS, throws a
  /// [PlatformException] with code INVALID_ARGUMENT, before anything is saved,
  /// if HealthKit does not accept the session's times: a session longer than 4
  /// days, HealthKit's maximum for a sleep sample, or one that ends in the year
  /// 4001 or later.
  Future<bool> writeSleepSession({
    required DateTime startTime,
    required DateTime endTime,
    List<SleepSessionStage> stages = const [],
    String? title,
    String? notes,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    if (platformType == HealthPlatformType.appleHealth &&
        [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }
    // The times are checked in the milliseconds the platform gets.
    final start = startTime.millisecondsSinceEpoch;
    final end = endTime.millisecondsSinceEpoch;
    if (start >= end) {
      throw ArgumentError("startTime must be before endTime");
    }
    _checkSleepStages(stages, start, end);
    await _checkIfHealthConnectAvailableOnAndroid();

    final args = <String, dynamic>{
      'startTime': start,
      'endTime': end,
      'title': title,
      'notes': notes,
      'recordingMethod': recordingMethod.toInt(),
      'stages': [
        for (final stage in stages)
          {
            'type': stage.type.name,
            'startTime': stage.startTime.millisecondsSinceEpoch,
            'endTime': stage.endTime.millisecondsSinceEpoch,
          },
      ],
    };
    final bool? success = await Health._channel.invokeMethod('writeSleepSession', args);
    return success ?? false;
  }
}

/// Throws an [ArgumentError] unless each of [stages] has a sleep stage type,
/// starts before it ends, is inside the session from [start] to [end] (epoch
/// milliseconds) and starts at or after the end of the stage before it.
void _checkSleepStages(List<SleepSessionStage> stages, int start, int end) {
  var previousStart = start;
  var previousEnd = start;
  for (final (index, stage) in stages.indexed) {
    final stageStart = stage.startTime.millisecondsSinceEpoch;
    final stageEnd = stage.endTime.millisecondsSinceEpoch;
    final name = 'stages[$index]';
    if (!SleepSessionStage._types.contains(stage.type)) {
      throw ArgumentError.value(stage, name, 'Not a sleep stage type');
    }
    if (stageStart >= stageEnd) {
      throw ArgumentError.value(stage, name, 'A stage must start before it ends');
    }
    if (stageStart < start || stageEnd > end) {
      throw ArgumentError.value(stage, name, 'A stage must be inside the session');
    }
    if (stageStart < previousStart) {
      throw ArgumentError.value(stage, name, 'Stages must be sorted by start time');
    }
    if (stageStart < previousEnd) {
      throw ArgumentError.value(stage, name, 'Stages must not overlap');
    }
    previousStart = stageStart;
    previousEnd = stageEnd;
  }
}
