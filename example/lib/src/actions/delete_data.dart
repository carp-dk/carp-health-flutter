part of '../../main.dart';

/// Deleting health data.
extension _DeleteDataActions on HealthAppState {
  /// Delete some random health data.
  Future<void> deleteData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(hours: 24));

    bool success = true;
    for (HealthDataType type in types) {
      success &= await health.delete(type: type, startTime: earlier, endTime: now);
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
