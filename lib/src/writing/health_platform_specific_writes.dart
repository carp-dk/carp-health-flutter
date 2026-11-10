part of '../../health.dart';

/// Part of [Health]: writing health data that only one platform supports,
/// audiograms and insulin delivery on iOS and activity intensity on Android.
// ignore: library_private_types_in_public_api
mixin HealthPlatformSpecificWrites on _HealthSupport {
  /// Saves audiogram into Apple Health. Not supported on Android.
  ///
  /// Returns true if successful, false if HealthKit could not save it.
  ///
  /// Parameters:
  ///   * [frequencies] - array of frequencies of the test, in Hz
  ///   * [leftEarSensitivities] - threshold in decibel (dBHL) for the left ear
  ///     at each frequency
  ///   * [rightEarSensitivities] - threshold in decibel (dBHL) for the right
  ///     ear at each frequency
  ///   * [startTime] - the start time when the audiogram is measured.
  ///     It must be equal to or earlier than [endTime].
  ///   * [endTime] - the end time when the audiogram is measured.
  ///     It must be equal to or later than [startTime].
  ///     Simply set [endTime] equal to [startTime] if the audiogram is measured
  ///     only at a specific point in time (default).
  ///   * [metadata] - optional HealthKit metadata: 'HKDeviceName' and
  ///     'HKExternalUUID', each optional, with String values; other keys are
  ///     ignored.
  ///
  /// Throws a [PlatformException] with code INVALID_ARGUMENT if HealthKit does
  /// not accept the audiogram: more than 30 frequencies, frequencies that are
  /// not unique and in ascending order, a frequency outside 0-30000 Hz or a
  /// threshold outside -20-160 dBHL, a metadata value that is not a String, or
  /// a [startTime]-[endTime] range longer than 4 days.
  Future<bool> writeAudiogram({
    required List<double> frequencies,
    required List<double> leftEarSensitivities,
    required List<double> rightEarSensitivities,
    required DateTime startTime,
    DateTime? endTime,
    Map<String, dynamic>? metadata,
  }) async {
    if (frequencies.isEmpty || leftEarSensitivities.isEmpty || rightEarSensitivities.isEmpty) {
      throw ArgumentError("frequencies, leftEarSensitivities and rightEarSensitivities can't be empty");
    }
    if (frequencies.length != leftEarSensitivities.length ||
        rightEarSensitivities.length != leftEarSensitivities.length) {
      throw ArgumentError("frequencies, leftEarSensitivities and rightEarSensitivities need to be of the same length");
    }
    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }
    if (Platform.isAndroid) {
      throw UnsupportedError("writeAudiogram is not supported on Android");
    }

    Map<String, dynamic> args = {
      'frequencies': frequencies,
      'leftEarSensitivities': leftEarSensitivities,
      'rightEarSensitivities': rightEarSensitivities,
      'dataTypeKey': HealthDataType.AUDIOGRAM.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'metadata': metadata,
    };
    return await Health._channel.invokeMethod('writeAudiogram', args) == true;
  }

  /// Saves insulin delivery record into Apple Health.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [units] - the number of units of insulin taken.
  ///  * [reason] - the insulin reason, basal or bolus.
  ///  * [startTime] - the start time when the meal was consumed.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when the meal was consumed.
  ///    It must be equal to or later than [startTime].
  Future<bool> writeInsulinDelivery(
    double units,
    InsulinDeliveryReason reason,
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    if (reason == InsulinDeliveryReason.NOT_SET) {
      throw ArgumentError("set a valid insulin delivery reason");
    }

    if (Platform.isAndroid) {
      throw UnsupportedError("writeInsulinDelivery is not supported on Android");
    }

    Map<String, dynamic> args = {
      'units': units,
      'reason': reason.index,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
    };

    bool? success = await Health._channel.invokeMethod('writeInsulinDelivery', args);
    return success ?? false;
  }

  /// Writes an `ActivityIntensityRecord` to Google Health Connect.
  ///
  /// This API is Android only.
  Future<bool> writeActivityIntensity({
    required ActivityIntensityLevel intensityLevel,
    required DateTime startTime,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
    String? clientRecordId,
    double? clientRecordVersion,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('writeActivityIntensity is only available on Android');
    }

    await _checkIfHealthConnectAvailableOnAndroid();

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    final intensityValue = intensityLevel.toAndroidValue();
    if (intensityValue == -1) {
      throw ArgumentError('Unknown activity intensity level provided.');
    }

    Map<String, dynamic> args = {
      'intensityType': intensityValue,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };

    final bool? success = await Health._channel.invokeMethod('writeActivityIntensity', args);
    return success ?? false;
  }
}
