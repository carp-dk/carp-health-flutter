part of '../../health.dart';

/// Part of [Health]: deleting the records of a type in a period of time, or
/// one record by its UUID or client record id.
// ignore: library_private_types_in_public_api
mixin HealthDataDeletion on _HealthSupport {
  /// Deletes all records of the given [type] for a given period of time.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [type] - the value's HealthDataType.
  ///  * [startTime] - the start time when this [value] is measured.
  ///    Must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    Must be equal to or later than [startTime].
  ///
  /// On iOS, a sleep type or headache severity deletes only the app's samples
  /// of that type. On Android, any sleep type deletes the app's whole sleep
  /// sessions in the range, with all their stages: Health Connect stores a
  /// night as one session (see [Health.writeSleepSession]).
  Future<bool> delete({required HealthDataType type, required DateTime startTime, DateTime? endTime}) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    Map<String, dynamic> args = {
      'dataTypeKey': type.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
    };
    bool? success = await Health._channel.invokeMethod('delete', args);
    return success ?? false;
  }

  /// Deletes a specific health record by its UUID.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [uuid] - The UUID of the health record to delete.
  ///  * [type] - The health data type of the record. Required on iOS.
  ///
  /// On Android, only the UUID is required. On iOS, both UUID and type are required.
  Future<bool> deleteByUUID({required String uuid, HealthDataType? type}) async {
    await _checkIfHealthConnectAvailableOnAndroid();

    if (uuid.isEmpty || uuid == "") {
      throw ArgumentError("UUID must not be empty.");
    }

    if (Platform.isIOS && type == null) {
      throw ArgumentError("On iOS, both UUID and type are required to delete a record.");
    }

    Map<String, dynamic> args = {'uuid': uuid, 'dataTypeKey': type?.name};

    bool? success = await Health._channel.invokeMethod('deleteByUUID', args);
    return success ?? false;
  }

  Future<bool> deleteByClientRecordId({
    required HealthDataType dataTypeKey,
    required String clientRecordId,
    String? recordId,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();

    Map<String, dynamic> args = {
      'dataTypeKey': dataTypeKey.name,
      'recordId': recordId,
      'clientRecordId': clientRecordId,
    };
    bool? success = await Health._channel.invokeMethod('deleteByClientRecordId', args);
    return success ?? false;
  }
}
