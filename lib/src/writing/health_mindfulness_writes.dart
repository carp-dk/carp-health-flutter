part of '../../health.dart';

/// Part of [Health]: writing a mindfulness session with its type, such as a
/// meditation or a breathing exercise.
// ignore: library_private_types_in_public_api
mixin HealthMindfulnessWrites on _HealthSupport {
  /// Write a mindfulness session from [startTime] to [endTime], for example a
  /// meditation.
  ///
  /// Returns true if the session was saved, false otherwise.
  ///
  /// Parameters:
  ///  * [startTime] - the start of the session. It must be before [endTime].
  ///  * [endTime] - the end of the session.
  ///  * [sessionType] - **Android only**: the type of the session,
  ///    [MindfulnessSessionType.UNKNOWN] by default.
  ///  * [title] - **Android only**: the title of the session.
  ///  * [notes] - **Android only**: notes about the session.
  ///  * [recordingMethod] - the recording method of the session, automatic by
  ///    default (on iOS this must be manual or automatic).
  ///
  /// On **Android** this is a Health Connect mindfulness session with its
  /// [sessionType], [title] and [notes]. On **iOS** it is a HealthKit mindful
  /// session, which has no type, title or notes: they are not stored. Reads
  /// return the session as a [HealthDataType.MINDFULNESS] data point whose
  /// value is its minutes; they do not return its type, title and notes.
  /// ([Health.writeHealthData] writes a session of type
  /// [MindfulnessSessionType.UNKNOWN] without a title and notes.)
  ///
  /// Request write access to [HealthDataType.MINDFULNESS] first.
  ///
  /// Throws an [ArgumentError], before anything is sent, if [startTime] is not
  /// before [endTime] or, on iOS, if [recordingMethod] is not manual or
  /// automatic. Throws an [UnsupportedError] if Health Connect is not
  /// available, and a [HealthException] with [HealthErrorCode.notSupported]
  /// if it has no mindfulness sessions (see
  /// [Health.isMindfulnessSessionAvailable]).
  Future<bool> writeMindfulnessSession({
    required DateTime startTime,
    required DateTime endTime,
    MindfulnessSessionType sessionType = MindfulnessSessionType.UNKNOWN,
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
    await _checkIfHealthConnectAvailableOnAndroid();
    await _checkIfDataTypeAvailableOnDevice(HealthDataType.MINDFULNESS);

    // The writeData call of writeHealthData with the session: HealthKit's
    // mindful session ignores the session type, title and notes.
    final args = <String, dynamic>{
      'value': (end - start) / Duration.millisecondsPerMinute,
      'dataTypeKey': HealthDataType.MINDFULNESS.name,
      'dataUnitKey': HealthDataUnit.MINUTE.name,
      'startTime': start,
      'endTime': end,
      'recordingMethod': recordingMethod.toInt(),
      'mindfulnessSessionType': sessionType.name,
      'title': title,
      'notes': notes,
    };
    final bool? success = await Health._channel.invokeMethod('writeData', args);
    return success ?? false;
  }
}
