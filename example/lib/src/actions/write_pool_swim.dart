part of '../../main.dart';

/// Writing a sample pool swim with its laps.
extension _WritePoolSwimActions on HealthAppState {
  /// Writes a pool swim of four 25 m lengths, a minute each, from [start]: two
  /// freestyle, one backstroke and one breaststroke. Returns true if it was
  /// saved.
  ///
  /// iOS saves the pool length as the lap length of the HealthKit workout, the
  /// laps as its lap events with their stroke styles, and the stroke count as
  /// its total. Android saves the laps in Health Connect with the pool length
  /// as their length and the stroke styles as segments over them, but not the
  /// stroke count. Fetch the workout to see them in its swimming details.
  Future<bool> writePoolSwim(DateTime start) {
    SwimmingLap lap(int minute, SwimmingStrokeStyle strokeStyle) => SwimmingLap(
      startTime: start.add(Duration(minutes: minute)),
      endTime: start.add(Duration(minutes: minute + 1)),
      strokeStyle: strokeStyle,
    );
    return health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.SWIMMING_POOL,
      title: "Pool swim",
      start: start,
      end: start.add(const Duration(minutes: 4)),
      totalDistance: 100,
      swimming: SwimmingDetails(
        poolLength: 25,
        laps: [
          lap(0, SwimmingStrokeStyle.freestyle),
          lap(1, SwimmingStrokeStyle.freestyle),
          lap(2, SwimmingStrokeStyle.backstroke),
          lap(3, SwimmingStrokeStyle.breaststroke),
        ],
      ),
      totalSwimmingStrokeCount: 72, // iOS only
    );
  }
}
