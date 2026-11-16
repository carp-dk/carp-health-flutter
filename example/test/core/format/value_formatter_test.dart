import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/value_formatter.dart';

final _from = DateTime(2026, 11, 16, 7);

HealthDataPoint _point(
  HealthDataType type,
  HealthValue value, {
  HealthPlatformType platform = HealthPlatformType.googleHealthConnect,
  Duration length = Duration.zero,
  Map<String, dynamic>? metadata,
}) => HealthDataPoint(
  uuid: 'uuid',
  value: value,
  type: type,
  unit: dataTypeToUnit[type]!,
  dateFrom: _from,
  dateTo: _from.add(length),
  sourcePlatform: platform,
  sourceDeviceId: 'device',
  sourceId: 'app',
  sourceName: 'App',
  metadata: metadata,
);

String _numeric(
  HealthDataType type,
  num value, {
  HealthPlatformType platform = HealthPlatformType.googleHealthConnect,
}) => formatPointValue(_point(type, NumericHealthValue(numericValue: value), platform: platform));

void main() {
  group('numeric values', () {
    test('show the unit symbol', () {
      expect(_numeric(HealthDataType.HEART_RATE, 72), '72 bpm');
      expect(_numeric(HealthDataType.WEIGHT, 72.456), '72.46 kg');
      expect(_numeric(HealthDataType.BODY_TEMPERATURE, 36.6), '36.6 °C');
      expect(_numeric(HealthDataType.STEPS, 12345), '12,345');
    });

    test('show time units as durations', () {
      expect(_numeric(HealthDataType.SLEEP_DEEP, 85.5), '1 h 25 min');
      expect(_numeric(HealthDataType.MINDFULNESS, 10), '10 min');
      expect(_numeric(HealthDataType.APPLE_MOVE_TIME, 90), '1 min 30 s');
    });

    test('scale percentages: HealthKit fractions, Health Connect 0 to 100', () {
      expect(_numeric(HealthDataType.BLOOD_OXYGEN, 0.97, platform: HealthPlatformType.appleHealth), '97%');
      expect(_numeric(HealthDataType.BLOOD_OXYGEN, 97), '97%');
    });

    test('show long distances in km and small masses in mg or µg', () {
      expect(_numeric(HealthDataType.DISTANCE_DELTA, 5234), '5.23 km');
      expect(_numeric(HealthDataType.DISTANCE_DELTA, 850), '850 m');
      expect(_numeric(HealthDataType.DIETARY_IRON, 0.012), '12 mg');
      expect(_numeric(HealthDataType.DIETARY_VITAMIN_D, 0.00002), '20 µg');
      expect(_numeric(HealthDataType.DIETARY_PROTEIN_CONSUMED, 0), '0 g');
    });

    test('read codes as words', () {
      expect(_numeric(HealthDataType.BLOOD_TYPE, 7.0), 'O+');
      expect(_numeric(HealthDataType.GENDER, 1), 'Female');
      expect(_numeric(HealthDataType.GENDER, 0), 'Not set');
      expect(_numeric(HealthDataType.BIRTH_DATE, 0), 'Not set');
      expect(_numeric(HealthDataType.BIRTH_DATE, DateTime(1990, 5, 17).millisecondsSinceEpoch / 1000), '17 May 1990');
      expect(_numeric(HealthDataType.APPLE_STAND_HOUR, 0), 'Stood');
      expect(_numeric(HealthDataType.HIGH_HEART_RATE_EVENT, 0), 'Detected');
      expect(_numeric(HealthDataType.WORKOUT_EFFORT_SCORE, 7), '7 / 10');
    });

    test('survive non-finite values', () {
      expect(_numeric(HealthDataType.HEART_RATE, double.nan), '–');
      expect(_numeric(HealthDataType.GENDER, double.nan), '–');
    });
  });

  group('typed values', () {
    test('a workout shows its type, length and totals', () {
      final workout = WorkoutHealthValue(
        workoutActivityType: HealthWorkoutActivityType.SWIMMING_POOL,
        totalDistance: 1500,
        totalEnergyBurned: 320,
        swimming: SwimmingDetails(
          poolLength: 25,
          laps: [SwimmingLap(startTime: _from, endTime: _from.add(const Duration(minutes: 1)))],
        ),
      );
      expect(
        formatPointValue(_point(HealthDataType.WORKOUT, workout, length: const Duration(minutes: 30))),
        'Swimming pool · 30 min · 1.5 km · 320 kcal · 1 lap',
      );
    });

    test('a meal shows its name, type and energy, or its macros', () {
      final lunch = NutritionHealthValue(name: 'Salad', mealType: 'LUNCH', calories: 412.4);
      expect(formatPointValue(_point(HealthDataType.NUTRITION, lunch)), 'Salad · Lunch · 412 kcal');
      final snack = NutritionHealthValue(mealType: 'SNACK', protein: 10, carbs: 20);
      expect(formatPointValue(_point(HealthDataType.NUTRITION, snack)), 'Snack · P 10 g · C 20 g');
    });

    test('an audiogram shows its frequency range', () {
      final audiogram = AudiogramHealthValue(
        frequencies: [250, 1000, 8000],
        leftEarSensitivities: [10, null, 20],
        rightEarSensitivities: [15, 15, 25],
      );
      expect(formatPointValue(_point(HealthDataType.AUDIOGRAM, audiogram)), '3 frequencies · 250–8,000 Hz');
    });

    test('an ECG shows its classification and heart rate', () {
      final ecg = ElectrocardiogramHealthValue(
        voltageValues: const [],
        averageHeartRate: 71.6,
        classification: ElectrocardiogramClassification.SINUS_RHYTHM,
      );
      expect(formatPointValue(_point(HealthDataType.ELECTROCARDIOGRAM, ecg)), 'Sinus rhythm · 72 bpm');
    });

    test('insulin, menstruation, intensity and skin temperature', () {
      expect(
        formatPointValue(
          _point(
            HealthDataType.INSULIN_DELIVERY,
            InsulinDeliveryHealthValue(units: 2.5, reason: InsulinDeliveryReason.BOLUS),
          ),
        ),
        '2.5 IU · Bolus',
      );
      expect(
        formatPointValue(
          _point(
            HealthDataType.MENSTRUATION_FLOW,
            MenstruationFlowHealthValue(flow: MenstrualFlow.medium, dateTime: _from, isStartOfCycle: true),
          ),
        ),
        'Medium flow · cycle start',
      );
      expect(
        formatPointValue(
          _point(
            HealthDataType.ACTIVITY_INTENSITY,
            ActivityIntensityHealthValue(intensityLevel: ActivityIntensityLevel.vigorous, minutes: 30),
          ),
        ),
        'Vigorous · 30 min',
      );
      expect(
        formatPointValue(
          _point(HealthDataType.SKIN_TEMPERATURE, SkinTemperatureHealthValue(temperatureDelta: 0.4, baseline: 33.5)),
        ),
        '33.9 °C (Δ +0.4)',
      );
      expect(
        formatPointValue(_point(HealthDataType.SKIN_TEMPERATURE, SkinTemperatureHealthValue(temperatureDelta: -0.2))),
        'Δ -0.2 °C',
      );
    });

    test('a route shows its locations, or that it needs consent', () {
      final route = WorkoutRouteHealthValue(
        locations: [WorkoutRouteLocation(latitude: 55.7, longitude: 12.5, timestamp: _from)],
      );
      expect(formatPointValue(_point(HealthDataType.WORKOUT_ROUTE, route)), '1 location');
      expect(
        formatPointValue(
          _point(
            HealthDataType.WORKOUT_ROUTE,
            WorkoutRouteHealthValue(locations: const []),
            metadata: {'route_requires_consent': true},
          ),
        ),
        'Route needs consent',
      );
    });
  });

  group('formatUnit', () {
    test('every unit has a symbol, empty only for unitless ones', () {
      const unitless = {
        HealthDataUnit.COUNT,
        HealthDataUnit.APPLE_EFFORT_SCORE,
        HealthDataUnit.UNKNOWN_UNIT,
        HealthDataUnit.NO_UNIT,
      };
      for (final unit in HealthDataUnit.values) {
        expect(formatUnit(unit).isEmpty, unitless.contains(unit), reason: unit.name);
      }
    });

    test('spot checks', () {
      expect(formatUnit(HealthDataUnit.BEATS_PER_MINUTE), 'bpm');
      expect(formatUnit(HealthDataUnit.MILLIGRAM_PER_DECILITER), 'mg/dL');
      expect(formatUnit(HealthDataUnit.DEGREE_FAHRENHEIT), '°F');
    });
  });
}
