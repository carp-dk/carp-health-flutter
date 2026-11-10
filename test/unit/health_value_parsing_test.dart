import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthDataPoint parsing', () {
    test('parses numeric health data points', () {
      final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.HEART_RATE, HealthFixtures.numericPoint(), null);

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
      // Only iOS sends these.
      expect(value.totalFlightsClimbed, isNull);
      expect(value.totalSwimmingStrokeCount, isNull);
    });

    test('parses the flights climbed and swimming strokes of iOS workouts', () {
      // HealthKit's totals, as iOS sends them.
      final swim = {
        ...HealthFixtures.workoutPoint(activityType: 'SWIMMING'),
        'totalFlightsClimbed': 2.0,
        'totalSwimmingStrokeCount': 640.0,
      };
      final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.WORKOUT, swim, HealthDataUnit.NO_UNIT.name);

      final value = point.value as WorkoutHealthValue;
      expect(value.totalFlightsClimbed, 2);
      expect(value.totalSwimmingStrokeCount, 640);

      final json = jsonDecode(jsonEncode(point.toJson())) as Map<String, dynamic>;
      final restored = HealthDataPoint.fromJson(json).value as WorkoutHealthValue;
      expect(restored.totalFlightsClimbed, 2);
      expect(restored.totalSwimmingStrokeCount, 640);
      expect(restored, value);
      expect(restored.hashCode, value.hashCode);

      // Both take part in ==.
      expect(WorkoutHealthValue.fromHealthDataPoint({...swim, 'totalFlightsClimbed': 3.0}), isNot(value));
      expect(WorkoutHealthValue.fromHealthDataPoint({...swim, 'totalSwimmingStrokeCount': 641.0}), isNot(value));
    });

    test('builds a workout summary from Android camelCase keys', () {
      final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.WORKOUT, {
        ...HealthFixtures.workoutPoint(),
        'totalSteps': 6200,
        'totalStepsUnit': 'COUNT',
      }, HealthDataUnit.NO_UNIT.name);

      final summary = point.workoutSummary;
      expect(summary, isNotNull);
      expect(summary!.workoutType, 'RUNNING');
      expect(summary.totalDistance, 5000);
      expect(summary.totalEnergyBurned, 200);
      expect(summary.totalSteps, 6200);
      expect(
        summary.toString(),
        'WorkoutSummary - workoutType: RUNNING, totalDistance: 5000, totalEnergyBurned: 200, totalSteps: 6200',
      );
    });

    test('builds a workout summary when Android sends no totals', () {
      final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.WORKOUT, {
        ...HealthFixtures.workoutPoint(),
        'totalDistance': null,
        'totalEnergyBurned': null,
      }, HealthDataUnit.NO_UNIT.name);

      final summary = point.workoutSummary;
      expect(summary, isNotNull);
      expect(summary!.workoutType, 'RUNNING');
      expect(summary.totalDistance, 0);
      expect(summary.totalEnergyBurned, 0);
      expect(summary.totalSteps, 0);
    });

    test('prefers the iOS snake_case summary keys when present', () {
      // iOS sends both: the summary's totals cut to whole numbers, and the workout value's.
      final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.WORKOUT, {
        ...HealthFixtures.workoutPoint(),
        'totalDistance': 4999.6,
        'totalEnergyBurned': 199.7,
        'workout_type': 'RUNNING',
        'total_distance': 4999,
        'total_energy_burned': 199,
      }, HealthDataUnit.NO_UNIT.name);

      final summary = point.workoutSummary;
      expect(summary, isNotNull);
      expect(summary!.workoutType, 'RUNNING');
      expect(summary.totalDistance, 4999);
      expect(summary.totalEnergyBurned, 199);
      expect(summary.totalSteps, 0);
    });

    test('leaves the workout summary null for other data types', () {
      final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.HEART_RATE, HealthFixtures.numericPoint(), null);

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
