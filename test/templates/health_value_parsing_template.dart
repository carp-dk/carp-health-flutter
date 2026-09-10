// Copy this file into test/unit and rename to *_test.dart to activate.

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthValue JSON parsing', () {
    test('NumericHealthValue round-trip', () {
      final dataPoint = HealthDataPoint(
        uuid: 'uuid-1',
        value: NumericHealthValue(numericValue: 72),
        type: HealthDataType.HEART_RATE,
        unit: HealthDataUnit.COUNT,
        dateFrom: DateTime(2025, 1, 1, 10, 0),
        dateTo: DateTime(2025, 1, 1, 10, 1),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'device-id',
        sourceId: 'source-id',
        sourceName: 'source-name',
        recordingMethod: RecordingMethod.automatic,
      );

      final json = dataPoint.toJson();
      final restored = HealthDataPoint.fromJson(json);

      expect(restored.type, HealthDataType.HEART_RATE);
      expect(restored.value, isA<NumericHealthValue>());
    });

    // TODO: Add coverage for the following HealthValue types.
    // - ActivityIntensityHealthValue
    // - WorkoutHealthValue
    // - WorkoutRouteHealthValue
    // - ElectrocardiogramHealthValue
    // - NutritionHealthValue
    // - InsulinDeliveryHealthValue
    // - MenstruationFlowHealthValue
    // - AudiogramHealthValue
  });
}
