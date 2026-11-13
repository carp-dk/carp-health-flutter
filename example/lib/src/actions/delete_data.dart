part of '../../main.dart';

/// Deleting health data.
extension _DeleteDataActions on HealthAppState {
  /// Delete some random health data.
  Future<void> deleteData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(hours: 24));

    bool success = true;
    final access = permissions;
    for (final (index, type) in types.indexed) {
      // Nothing to delete for what the app cannot write: the types it may only read, and on
      // Android BODY_MASS_INDEX (computed from WEIGHT and HEIGHT) and WORKOUT_ROUTE (part of its
      // workout).
      if (access[index] == HealthDataAccess.READ ||
          (Platform.isAndroid && const {HealthDataType.BODY_MASS_INDEX, HealthDataType.WORKOUT_ROUTE}.contains(type))) {
        continue;
      }
      final deleted = await health.delete(type: type, startTime: earlier, endTime: now);
      if (!deleted) debugPrint('Could not delete $type');
      success &= deleted;
    }

    // To delete a record by UUID - call the `health.deleteByUUID` method:
    /**
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startDate,
        endTime: endDate,
      );
      
      if (healthData.isNotEmpty) {
        print("DELETING: ${healthData.first.toJson()}");
        String uuid = healthData.first.uuid;
        
        success &= await health.deleteByUUID(
          type: HealthDataType.STEPS,
          uuid: uuid,
        );
        
      }
     */

    setState(() {
      _state = success ? AppState.DATA_DELETED : AppState.DATA_NOT_DELETED;
    });
  }
}
