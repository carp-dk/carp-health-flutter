part of 'health.dart';

bool _fromJsonFunctionsRegistered = false;

/// Register all the fromJson functions for the health domain classes.
void _registerFromJsonFunctions() {
  if (_fromJsonFunctionsRegistered) return;

  // Protocol classes
  FromJsonFactory().registerAll([
    HealthValue(),
    NumericHealthValue(numericValue: 12),
    WorkoutHealthValue(workoutActivityType: HealthWorkoutActivityType.RUNNING),
    AudiogramHealthValue(frequencies: [], leftEarSensitivities: [], rightEarSensitivities: []),
    ElectrocardiogramHealthValue(voltageValues: []),
    ElectrocardiogramVoltageValue(voltage: 12, timeSinceSampleStart: 0),
    NutritionHealthValue(),
    WorkoutRouteHealthValue(locations: []),
    WorkoutRouteLocation(latitude: 0, longitude: 0, timestamp: DateTime.now()),
    MenstruationFlowHealthValue(flow: null, dateTime: DateTime.now()),
    InsulinDeliveryHealthValue(units: 0.0, reason: InsulinDeliveryReason.NOT_SET),
    ActivityIntensityHealthValue(intensityLevel: ActivityIntensityLevel.unknown, minutes: 0),
  ]);

  _fromJsonFunctionsRegistered = true;
}
