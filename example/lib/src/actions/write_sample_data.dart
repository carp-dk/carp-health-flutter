part of '../../main.dart';

/// Writing sample data for a wide range of data types and write methods.
extension _WriteSampleDataActions on HealthAppState {
  /// Add some random health data.
  /// Note that you should ensure that you have permissions to add the
  /// following data types.
  Future<void> addData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(minutes: 20));

    // Add data for supported types
    // NOTE: These are only the ones supported on Androids new API Health Connect.
    // Both Android's Health Connect and iOS' HealthKit have more types that we support in the enum list [HealthDataType]
    // Add more - like AUDIOGRAM, HEADACHE_SEVERE etc. to try them.
    bool success = true;

    // misc. health data examples using the writeHealthData() method
    success &= await health.writeHealthData(
      value: 1.925,
      type: HealthDataType.HEIGHT,
      startTime: earlier,
      endTime: now,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await health.writeHealthData(
      value: 90,
      type: HealthDataType.WEIGHT,
      startTime: now,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await health.writeHealthData(
      value: 42.5,
      type: HealthDataType.VO2_MAX,
      startTime: now,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await health.writeHealthData(
      value: 90,
      type: HealthDataType.HEART_RATE,
      startTime: earlier,
      endTime: now,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await health.writeHealthData(
      value: 90,
      type: HealthDataType.STEPS,
      startTime: earlier,
      endTime: now,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await health.writeHealthData(
      value: 200,
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      startTime: earlier,
      endTime: now,
      clientRecordId: "uniqueID1234",
      clientRecordVersion: 1,
    );
    success &= await health.writeHealthData(
      value: 70,
      type: HealthDataType.HEART_RATE,
      startTime: earlier,
      endTime: now,
    );
    success &= await health.writeHealthData(
      value: 37,
      type: HealthDataType.BODY_TEMPERATURE,
      startTime: earlier,
      endTime: now,
    );
    success &= await health.writeHealthData(
      value: 105,
      type: HealthDataType.BLOOD_GLUCOSE,
      startTime: earlier,
      endTime: now,
    );
    success &= await health.writeHealthData(value: 1.8, type: HealthDataType.WATER, startTime: earlier, endTime: now);

    // a short night of sleep: one session with its stages, five minutes each
    // (on Android, each sleep value written with writeHealthData would be a session of its own)
    SleepSessionStage stage(HealthDataType type, int minute) => SleepSessionStage(
      type: type,
      startTime: earlier.add(Duration(minutes: minute)),
      endTime: earlier.add(Duration(minutes: minute + 5)),
    );
    success &= await health.writeSleepSession(
      startTime: earlier,
      endTime: now,
      stages: [
        stage(HealthDataType.SLEEP_LIGHT, 0),
        stage(HealthDataType.SLEEP_DEEP, 5),
        stage(HealthDataType.SLEEP_REM, 10),
        stage(HealthDataType.SLEEP_AWAKE, 15),
      ],
      title: 'Sample night',
    );
    success &= await health.writeHealthData(
      value: 22,
      type: HealthDataType.LEAN_BODY_MASS,
      startTime: earlier,
      endTime: now,
    );

    if (Platform.isAndroid) {
      success &= await health.writeActivityIntensity(
        intensityLevel: ActivityIntensityLevel.moderate,
        startTime: earlier,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );
    }

    // specialized write methods
    success &= await health.writeBloodOxygen(saturation: 98, startTime: earlier, endTime: now);
    success &= await health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.AMERICAN_FOOTBALL,
      title: "Random workout name that shows up in Health Connect",
      start: now.subtract(const Duration(minutes: 15)),
      end: now,
      totalDistance: 2430,
      totalEnergyBurned: 400,
    );
    success &= await health.writeBloodPressure(
      systolic: 90,
      diastolic: 80,
      startTime: now,
      clientRecordId: "uniqueID1234",
      clientRecordVersion: 2,
    );
    success &= await health.writeMeal(
      mealType: MealType.SNACK,
      clientRecordId: "uniqueID1234",
      clientRecordVersion: 1.4,
      startTime: earlier,
      endTime: now,
      caloriesConsumed: 1000,
      carbohydrates: 50,
      protein: 25,
      fatTotal: 50,
      name: "Banana",
      caffeine: 0.002,
      vitaminA: 0.001,
      vitaminC: 0.002,
      vitaminD: 0.003,
      vitaminE: 0.004,
      vitaminK: 0.005,
      b1Thiamin: 0.006,
      b2Riboflavin: 0.007,
      b3Niacin: 0.008,
      b5PantothenicAcid: 0.009,
      b6Pyridoxine: 0.010,
      b7Biotin: 0.011,
      b9Folate: 0.012,
      b12Cobalamin: 0.013,
      calcium: 0.015,
      copper: 0.016,
      iodine: 0.017,
      iron: 0.018,
      magnesium: 0.019,
      manganese: 0.020,
      phosphorus: 0.021,
      potassium: 0.022,
      selenium: 0.023,
      sodium: 0.024,
      zinc: 0.025,
      water: 0.026,
      molybdenum: 0.027,
      chloride: 0.028,
      chromium: 0.029,
      cholesterol: 0.030,
      fiber: 0.031,
      fatMonounsaturated: 0.032,
      fatPolyunsaturated: 0.033,
      fatUnsaturated: 0.065,
      fatTransMonoenoic: 0.65,
      fatSaturated: 066,
      sugar: 0.067,
      recordingMethod: RecordingMethod.manual,
    );

    // Store an Audiogram - only available on iOS
    // const frequencies = [125.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0];
    // const leftEarSensitivities = [49.0, 54.0, 89.0, 52.0, 77.0, 35.0];
    // const rightEarSensitivities = [76.0, 66.0, 90.0, 22.0, 85.0, 44.5];
    // success &= await health.writeAudiogram(
    //   frequencies,
    //   leftEarSensitivities,
    //   rightEarSensitivities,
    //   now,
    //   now,
    //   metadata: {
    //     "HKExternalUUID": "uniqueID",
    //     "HKDeviceName": "bluetooth headphone",
    //   },
    // );

    success &= await health.writeMenstruationFlow(
      flow: MenstrualFlow.medium,
      isStartOfCycle: true,
      startTime: earlier,
      endTime: now,
    );

    writeSkinTemperatureSample();

    if (Platform.isIOS) {
      success &= await health.writeInsulinDelivery(5, InsulinDeliveryReason.BOLUS, earlier, now);
      success &= await health.writeHealthData(
        value: 30,
        type: HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        startTime: earlier,
        endTime: now,
      );
      success &= await health.writeHealthData(
        value: 1.5, // 1.5 m/s (typical walking speed)
        type: HealthDataType.WALKING_SPEED,
        startTime: earlier,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );
    } else {
      success &= await health.writeHealthData(
        value: 2.0, // 2.0 m/s (typical jogging speed)
        type: HealthDataType.SPEED,
        startTime: earlier,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );
      success &= await health.writeHealthData(
        value: 30,
        type: HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        startTime: earlier,
        endTime: now,
      );
    }

    // Available on iOS 16.0+ only
    if (_isIOS16OrNewer) {
      success &= await health.writeHealthData(
        value: 22,
        type: HealthDataType.WATER_TEMPERATURE,
        startTime: earlier,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );

      success &= await health.writeHealthData(
        value: 55,
        type: HealthDataType.UNDERWATER_DEPTH,
        startTime: earlier,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );
      success &= await health.writeHealthData(
        value: 4.3,
        type: HealthDataType.UV_INDEX,
        startTime: earlier,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );
    } else if (Platform.isIOS) {
      debugPrint('Skipping WATER_TEMPERATURE, UNDERWATER_DEPTH, and UV_INDEX writes on iOS < 16.');
    }

    // A mindfulness session is the time from its start to its end. On Android it
    // needs a Health Connect that has mindfulness sessions, and it keeps the
    // session type and title, which iOS does not store.
    if (await health.isMindfulnessSessionAvailable()) {
      success &= await health.writeMindfulnessSession(
        startTime: earlier,
        endTime: now,
        sessionType: MindfulnessSessionType.BREATHING,
        title: 'Morning practice',
        recordingMethod: RecordingMethod.automatic,
      );
    }

    setState(() {
      _state = success ? AppState.DATA_ADDED : AppState.DATA_NOT_ADDED;
    });
  }
}
