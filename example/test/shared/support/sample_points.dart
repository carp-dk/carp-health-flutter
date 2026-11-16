/// Real `HealthDataPoint`s of every kind of `HealthValue`, as the plugin returns them, for the shared
/// widget tests.
library;

import 'dart:math' as math;

import 'package:health/health.dart';

/// The start of every sample: a fixed morning, so that tests do not depend on the clock.
final DateTime sampleStart = DateTime(2026, 3, 14, 7);

/// A data point of [type] holding [value], from [sampleStart] for [duration], read on [platform].
HealthDataPoint samplePoint(
  HealthDataType type,
  HealthValue value, {
  HealthDataUnit? unit,
  String uuid = 'uuid-1',
  Duration duration = Duration.zero,
  HealthPlatformType platform = HealthPlatformType.googleHealthConnect,
  RecordingMethod recordingMethod = RecordingMethod.automatic,
  String sourceName = 'com.example.watch',
  Map<String, dynamic>? metadata,
  String? deviceModel,
}) => HealthDataPoint(
  uuid: uuid,
  value: value,
  type: type,
  unit: unit ?? dataTypeToUnit[type]!,
  dateFrom: sampleStart,
  dateTo: sampleStart.add(duration),
  sourcePlatform: platform,
  sourceDeviceId: 'device-42',
  sourceId: platform == HealthPlatformType.appleHealth ? 'com.apple.health' : '',
  sourceName: sourceName,
  recordingMethod: recordingMethod,
  metadata: metadata,
  deviceModel: deviceModel,
);

/// A heart rate of [bpm].
HealthDataPoint heartRatePoint({num bpm = 72, String uuid = 'uuid-hr'}) => samplePoint(
  HealthDataType.HEART_RATE,
  NumericHealthValue(numericValue: bpm),
  uuid: uuid,
  deviceModel: 'Pixel Watch 2',
);

/// 95 minutes of deep sleep: the plugin reports sleep stages as their length in minutes.
HealthDataPoint deepSleepPoint() =>
    samplePoint(HealthDataType.SLEEP_DEEP, NumericHealthValue(numericValue: 95), duration: const Duration(minutes: 95));

/// A HealthKit blood oxygen of 97 %, which HealthKit reports as the fraction 0.97.
HealthDataPoint iosBloodOxygenPoint() => samplePoint(
  HealthDataType.BLOOD_OXYGEN,
  NumericHealthValue(numericValue: 0.97),
  platform: HealthPlatformType.appleHealth,
  recordingMethod: RecordingMethod.manual,
);

/// Blood type A+ (HealthKit characteristic code 1).
HealthDataPoint bloodTypePoint() => samplePoint(
  HealthDataType.BLOOD_TYPE,
  NumericHealthValue(numericValue: 1),
  platform: HealthPlatformType.appleHealth,
);

/// Steps over an hour as `getHealthIntervalDataFromTypes` returns them: an aggregate without a UUID.
HealthDataPoint stepsIntervalPoint() => samplePoint(
  HealthDataType.STEPS,
  NumericHealthValue(numericValue: 1234),
  uuid: '',
  duration: const Duration(hours: 1),
  sourceName: 'com.google.android.apps.fitness, com.example.watch',
);

/// A HealthKit pool swim: 1 km in a 25 m pool, three laps, a pause and HealthKit's extra fields.
HealthDataPoint poolSwimPoint() {
  DateTime at(int minute) => sampleStart.add(Duration(minutes: minute));
  return samplePoint(
    HealthDataType.WORKOUT,
    WorkoutHealthValue(
      workoutActivityType: HealthWorkoutActivityType.SWIMMING_POOL,
      totalDistance: 1000,
      totalDistanceUnit: HealthDataUnit.METER,
      totalEnergyBurned: 300,
      totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      totalSwimmingStrokeCount: 420,
      duration: 1680,
      avgMets: 8.5,
      indoorWorkout: true,
      swimming: SwimmingDetails(
        poolLength: 25,
        laps: [
          SwimmingLap(startTime: at(1), endTime: at(2), strokeStyle: SwimmingStrokeStyle.freestyle),
          SwimmingLap(startTime: at(2), endTime: at(3), strokeStyle: SwimmingStrokeStyle.backstroke),
          SwimmingLap(startTime: at(3), endTime: at(4), strokeStyle: SwimmingStrokeStyle.butterfly),
        ],
      ),
      workoutEvents: [
        WorkoutEvent(type: WorkoutEventType.pause, start: at(10), end: at(10)),
        WorkoutEvent(type: WorkoutEventType.resume, start: at(12), end: at(12)),
        WorkoutEvent(type: WorkoutEventType.segment, start: at(12), end: at(20)),
      ],
    ),
    uuid: 'uuid-swim',
    duration: const Duration(minutes: 30),
    platform: HealthPlatformType.appleHealth,
    recordingMethod: RecordingMethod.active,
  );
}

/// A banana as `writeMeal` writes it, with two micronutrients.
HealthDataPoint bananaPoint() => samplePoint(
  HealthDataType.NUTRITION,
  NutritionHealthValue(
    name: 'Banana',
    mealType: 'SNACK',
    calories: 105,
    protein: 1.3,
    carbs: 27,
    fat: 0.4,
    vitaminC: 0.0103,
    potassium: 0.422,
  ),
  uuid: 'uuid-meal',
  recordingMethod: RecordingMethod.manual,
);

/// An audiogram of four frequencies; the left ear was not tested at 4 kHz.
HealthDataPoint audiogramPoint() => samplePoint(
  HealthDataType.AUDIOGRAM,
  AudiogramHealthValue(
    frequencies: [500, 1000, 2000, 4000],
    leftEarSensitivities: [10, 15, 20, null],
    rightEarSensitivities: [5, 10, 25, 30],
  ),
  platform: HealthPlatformType.appleHealth,
);

/// A 30 second Apple Watch ECG in sinus rhythm: 600 voltage samples of a 64 bpm trace.
HealthDataPoint ecgPoint() => samplePoint(
  HealthDataType.ELECTROCARDIOGRAM,
  ElectrocardiogramHealthValue(
    voltageValues: [
      for (var i = 0; i < 600; i++)
        ElectrocardiogramVoltageValue(
          voltage: math.pow(math.sin(i * math.pi * 64 / 60 / 20), 16) * 0.0012,
          timeSinceSampleStart: i / 20,
        ),
    ],
    averageHeartRate: 64,
    samplingFrequency: 20,
    classification: ElectrocardiogramClassification.SINUS_RHYTHM,
  ),
  platform: HealthPlatformType.appleHealth,
  duration: const Duration(seconds: 30),
);

/// A route of five locations a minute apart, belonging to the workout `uuid-run`.
HealthDataPoint routePoint() => samplePoint(
  HealthDataType.WORKOUT_ROUTE,
  WorkoutRouteHealthValue(
    workoutUuid: 'uuid-run',
    locations: [
      for (var i = 0; i < 5; i++)
        WorkoutRouteLocation(
          latitude: 55.7856 + i * 0.001,
          longitude: 12.5218 + i * 0.0015,
          timestamp: sampleStart.add(Duration(minutes: i)),
          altitude: 20.0 + i,
        ),
    ],
  ),
  uuid: 'uuid-route',
  duration: const Duration(minutes: 4),
);

/// Another app's route read without the Exercise routes permission: no locations, marked in metadata.
HealthDataPoint routeNeedingConsentPoint() => samplePoint(
  HealthDataType.WORKOUT_ROUTE,
  WorkoutRouteHealthValue(locations: const []),
  metadata: const {'route_requires_consent': true},
);

/// A HealthKit light flow on the first day of a cycle, entered by the user.
HealthDataPoint menstruationPoint() => samplePoint(
  HealthDataType.MENSTRUATION_FLOW,
  MenstruationFlowHealthValue(
    flow: MenstrualFlow.light,
    dateTime: sampleStart,
    isStartOfCycle: true,
    wasUserEntered: true,
  ),
  platform: HealthPlatformType.appleHealth,
);

/// A 4.5 IU bolus of insulin.
HealthDataPoint insulinPoint() => samplePoint(
  HealthDataType.INSULIN_DELIVERY,
  InsulinDeliveryHealthValue(units: 4.5, reason: InsulinDeliveryReason.BOLUS),
  platform: HealthPlatformType.appleHealth,
);

/// A wrist skin temperature 0.4 °C over a 33.1 °C baseline.
HealthDataPoint skinTemperaturePoint() => samplePoint(
  HealthDataType.SKIN_TEMPERATURE,
  SkinTemperatureHealthValue(
    temperatureDelta: 0.4,
    baseline: 33.1,
    measurementLocation: SkinTemperatureMeasurementLocation.wrist,
  ),
);

/// 25 minutes of vigorous activity.
HealthDataPoint activityIntensityPoint() => samplePoint(
  HealthDataType.ACTIVITY_INTENSITY,
  ActivityIntensityHealthValue(intensityLevel: ActivityIntensityLevel.vigorous, minutes: 25),
  duration: const Duration(minutes: 25),
);

/// One data point of every kind of `HealthValue` the plugin returns, with the cases the views treat
/// apart (an interval without a UUID, a route without consent), by a name for test descriptions.
Map<String, HealthDataPoint> everyKindOfPoint() => {
  'heart rate': heartRatePoint(),
  'deep sleep': deepSleepPoint(),
  'iOS blood oxygen': iosBloodOxygenPoint(),
  'blood type': bloodTypePoint(),
  'steps interval': stepsIntervalPoint(),
  'pool swim': poolSwimPoint(),
  'meal': bananaPoint(),
  'audiogram': audiogramPoint(),
  'ECG': ecgPoint(),
  'route': routePoint(),
  'route needing consent': routeNeedingConsentPoint(),
  'menstruation': menstruationPoint(),
  'insulin': insulinPoint(),
  'skin temperature': skinTemperaturePoint(),
  'activity intensity': activityIntensityPoint(),
};
