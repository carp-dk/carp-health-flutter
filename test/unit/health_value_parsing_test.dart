import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthDataPoint parsing', () {
    test('parses numeric health data points', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.HEART_RATE,
        HealthFixtures.numericPoint(),
        null,
      );

      expect(point.type, HealthDataType.HEART_RATE);
      expect(point.value, isA<NumericHealthValue>());
      final value = point.value as NumericHealthValue;
      expect(value.numericValue, 72);
    });

    test('parses workout health data points', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT,
        HealthFixtures.workoutPoint(),
        HealthDataUnit.NO_UNIT.name,
      );

      expect(point.type, HealthDataType.WORKOUT);
      expect(point.value, isA<WorkoutHealthValue>());
      final value = point.value as WorkoutHealthValue;
      expect(value.workoutActivityType, HealthWorkoutActivityType.RUNNING);
      expect(value.totalEnergyBurned, 200);
      expect(value.totalDistance, 5000);
    });

    test('builds a workout summary from Android camelCase keys', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT,
        {...HealthFixtures.workoutPoint(), 'totalSteps': 6200, 'totalStepsUnit': 'COUNT'},
        HealthDataUnit.NO_UNIT.name,
      );

      final summary = point.workoutSummary;
      expect(summary, isNotNull);
      expect(summary!.workoutType, 'RUNNING');
      expect(summary.totalDistance, 5000);
      expect(summary.totalEnergyBurned, 200);
      expect(summary.totalSteps, 6200);
    });

    test('builds a workout summary when Android sends no totals', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT,
        {...HealthFixtures.workoutPoint(), 'totalDistance': null, 'totalEnergyBurned': null},
        HealthDataUnit.NO_UNIT.name,
      );

      final summary = point.workoutSummary;
      expect(summary, isNotNull);
      expect(summary!.workoutType, 'RUNNING');
      expect(summary.totalDistance, 0);
      expect(summary.totalEnergyBurned, 0);
      expect(summary.totalSteps, 0);
    });

    test('prefers the iOS snake_case summary keys when present', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT,
        {
          ...HealthFixtures.workoutPoint(),
          'workout_type': 'running',
          'total_distance': 4999,
          'total_energy_burned': 199,
        },
        HealthDataUnit.NO_UNIT.name,
      );

      final summary = point.workoutSummary;
      expect(summary, isNotNull);
      expect(summary!.workoutType, 'running');
      expect(summary.totalDistance, 4999);
      expect(summary.totalEnergyBurned, 199);
    });

    test('leaves the workout summary null for other data types', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.HEART_RATE,
        HealthFixtures.numericPoint(),
        null,
      );

      expect(point.workoutSummary, isNull);
    });

    test('parses workout route health data points', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT_ROUTE,
        HealthFixtures.workoutRoutePoint(),
        HealthDataUnit.NO_UNIT.name,
      );

      expect(point.type, HealthDataType.WORKOUT_ROUTE);
      expect(point.value, isA<WorkoutRouteHealthValue>());
      final value = point.value as WorkoutRouteHealthValue;
      expect(value.locations, hasLength(1));
      expect(value.workoutUuid, 'workout-uuid-1');
      expect(value.locations.first.latitude, 37.3349);
    });
  });
}
