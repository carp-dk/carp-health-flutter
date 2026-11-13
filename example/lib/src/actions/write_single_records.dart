part of '../../main.dart';

/// Writing single records, each returning the UUID of the new record.
extension _WriteSingleRecordActions on HealthAppState {
  // Add single steps data (health data)
  Future<void> addSingleHealthData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(minutes: 20));

    final uuid = await health.writeHealthDataUUID(
      value: 2130,
      type: HealthDataType.STEPS,
      startTime: earlier,
      endTime: now,
      recordingMethod: RecordingMethod.manual,
    );

    bool success = uuid != null;
    setState(() {
      _state = success ? AppState.DATA_ADDED : AppState.DATA_NOT_ADDED;
    });
  }

  // Add single running data (workout data)
  Future<void> addSingleWorkoutData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(minutes: 20));

    final uuid = await health.writeWorkoutDataUUID(
      activityType: HealthWorkoutActivityType.RUNNING,
      title: "New RUNNING activity",
      start: earlier,
      end: now,
      totalDistance: 2430,
      totalEnergyBurned: 400,
    );

    bool success = uuid != null;
    setState(() {
      _state = success ? AppState.DATA_ADDED : AppState.DATA_NOT_ADDED;
    });
  }
}
