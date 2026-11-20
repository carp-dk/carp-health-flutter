/// The workout steps of the sample data: a workout, a pool swim with laps and a run written with
/// `writeWorkoutDataUUID`, ported from the old example.
library;

import 'package:health/health.dart';

import '../forms/common/write_outcome.dart';
import 'sample_step.dart';
import 'sample_steps.dart';

/// On Android a workout's distance and energy are records of their own, which need write access.
const List<HealthDataType> workoutTotals = [HealthDataType.DISTANCE_DELTA, HealthDataType.TOTAL_CALORIES_BURNED];

/// The workout steps, built like the other [SampleSteps].
extension SampleWorkoutSteps on SampleSteps {
  /// A 15-minute American football workout with its distance and energy.
  SampleStep workout() => boolStep(
    'Workout',
    'writeWorkoutData',
    HealthDataType.WORKOUT,
    'American football · 2.43 km · 400 kcal',
    (health) => health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.AMERICAN_FOOTBALL,
      title: 'Sample football practice',
      start: now.subtract(const Duration(minutes: 15)),
      end: now,
      totalDistance: 2430,
      totalEnergyBurned: 400,
    ),
    extraAccess: workoutTotals,
  );

  /// A pool swim of four 25 m lengths, a minute each, in three stroke styles; iOS also stores the
  /// stroke count.
  SampleStep poolSwim() {
    SwimmingLap lap(int minute, SwimmingStrokeStyle style) => SwimmingLap(
      startTime: earlier.add(Duration(minutes: minute)),
      endTime: earlier.add(Duration(minutes: minute + 1)),
      strokeStyle: style,
    );
    return boolStep(
      'Pool swim',
      'writeWorkoutData',
      HealthDataType.WORKOUT,
      '4 × 25 m laps · 100 m',
      (health) => health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.SWIMMING_POOL,
        title: 'Sample pool swim',
        start: earlier,
        end: earlier.add(const Duration(minutes: 4)),
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
        totalSwimmingStrokeCount: isIOS ? 72 : null,
      ),
      extraAccess: workoutTotals,
    );
  }

  /// A run written with `writeWorkoutDataUUID`, whose UUID a workout route can be attached to.
  SampleStep runWithUuid() {
    const method = 'writeWorkoutDataUUID';
    const description = 'Running · 2.43 km · 400 kcal';
    return SampleStep(
      title: 'Run (single record)',
      method: method,
      type: HealthDataType.WORKOUT,
      description: description,
      extraAccess: workoutTotals,
      write: (health) async {
        final uuid = await health.writeWorkoutDataUUID(
          activityType: HealthWorkoutActivityType.RUNNING,
          title: 'Sample run',
          start: earlier,
          end: now,
          totalDistance: 2430,
          totalEnergyBurned: 400,
        );
        return WriteOutcome.fromUuid(method, HealthDataType.WORKOUT, description, uuid);
      },
    );
  }
}
