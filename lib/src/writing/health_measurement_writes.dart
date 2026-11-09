part of '../../health.dart';

/// Part of [Health]: writing blood pressure, blood oxygen and menstruation
/// flow.
// ignore: library_private_types_in_public_api
mixin HealthMeasurementWrites on _HealthSupport {
  /// Saves a blood pressure record.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [systolic] - the systolic part of the blood pressure.
  ///  * [diastolic] - the diastolic part of the blood pressure.
  ///  * [startTime] - the start time when this [value] is measured.
  ///    Must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    Must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the blood pressure is measured
  ///    only at a specific point in time. If omitted, [endTime] is set to [startTime].
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeBloodPressure({
    required int systolic,
    required int diastolic,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    Map<String, dynamic> args = {
      'systolic': systolic,
      'diastolic': diastolic,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };
    return await Health._channel.invokeMethod('writeBloodPressure', args) == true;
  }

  /// Saves blood oxygen saturation record.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [saturation] - the saturation of the blood oxygen in percentage
  ///  * [startTime] - the start time when this [saturation] is measured.
  ///    Must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [saturation] is measured.
  ///    Must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the blood oxygen saturation
  ///    is measured only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeBloodOxygen({
    required double saturation,
    required DateTime startTime,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }
    bool? success;

    if (Platform.isIOS) {
      success = await writeHealthData(
        value: saturation,
        type: HealthDataType.BLOOD_OXYGEN,
        startTime: startTime,
        endTime: endTime,
        recordingMethod: recordingMethod,
      );
    } else if (Platform.isAndroid) {
      Map<String, dynamic> args = {
        'value': saturation,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'dataTypeKey': HealthDataType.BLOOD_OXYGEN.name,
        'recordingMethod': recordingMethod.toInt(),
      };
      success = await Health._channel.invokeMethod('writeBloodOxygen', args);
    }
    return success ?? false;
  }

  /// Save menstruation flow into Apple Health and Google Health Connect.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [flow] - the menstrual flow
  ///  * [startTime] - the start time when the menstrual flow is measured.
  ///  * [endTime] - the start time when the menstrual flow is measured.
  ///  * [isStartOfCycle] - A bool that indicates whether the sample represents
  ///    the start of a menstrual cycle.
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeMenstruationFlow({
    required MenstrualFlow flow,
    required DateTime startTime,
    required DateTime endTime,
    required bool isStartOfCycle,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    var value = Platform.isAndroid ? MenstrualFlow.toHealthConnect(flow) : flow.index;

    if (value == -1) {
      throw ArgumentError("$flow is not a valid menstrual flow value for $platformType");
    }

    Map<String, dynamic> args = {
      'value': value,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'isStartOfCycle': isStartOfCycle,
      'dataTypeKey': HealthDataType.MENSTRUATION_FLOW.name,
      'recordingMethod': recordingMethod.toInt(),
    };
    return await Health._channel.invokeMethod('writeMenstruationFlow', args) == true;
  }
}
