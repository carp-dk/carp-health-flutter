part of '../../health.dart';

/// The body position of the user when a blood pressure measurement was taken.
///
/// Maps to the `BODY_POSITION_*` constants of the Health Connect
/// `BloodPressureRecord` on Android. Not available on iOS.
enum BloodPressureBodyPosition {
  unknown,
  standingUp,
  sittingDown,
  lyingDown,
  reclining;

  static BloodPressureBodyPosition fromAndroidValue(int? value) => switch (value) {
    1 => standingUp,
    2 => sittingDown,
    3 => lyingDown,
    4 => reclining,
    _ => unknown,
  };

  int toAndroidValue() => switch (this) {
    unknown => 0,
    standingUp => 1,
    sittingDown => 2,
    lyingDown => 3,
    reclining => 4,
  };
}

/// The arm and part of the arm where a blood pressure measurement was taken.
///
/// Maps to the `MEASUREMENT_LOCATION_*` constants of the Health Connect
/// `BloodPressureRecord` on Android. Not available on iOS.
enum BloodPressureMeasurementLocation {
  unknown,
  leftWrist,
  rightWrist,
  leftUpperArm,
  rightUpperArm;

  static BloodPressureMeasurementLocation fromAndroidValue(int? value) => switch (value) {
    1 => leftWrist,
    2 => rightWrist,
    3 => leftUpperArm,
    4 => rightUpperArm,
    _ => unknown,
  };

  int toAndroidValue() => switch (this) {
    unknown => 0,
    leftWrist => 1,
    rightWrist => 2,
    leftUpperArm => 3,
    rightUpperArm => 4,
  };
}

/// A systolic or diastolic blood pressure value, with the body position and
/// measurement location of the measurement.
///
/// Returned for [HealthDataType.BLOOD_PRESSURE_SYSTOLIC] and
/// [HealthDataType.BLOOD_PRESSURE_DIASTOLIC]. It is a [NumericHealthValue], so
/// code that reads only [numericValue] does not need to change.
///
/// On iOS, [bodyPosition] and [measurementLocation] are always `unknown`.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class BloodPressureHealthValue extends NumericHealthValue {
  @JsonKey(name: 'body_position')
  BloodPressureBodyPosition bodyPosition;

  @JsonKey(name: 'measurement_location')
  BloodPressureMeasurementLocation measurementLocation;

  BloodPressureHealthValue({
    required super.numericValue,
    this.bodyPosition = BloodPressureBodyPosition.unknown,
    this.measurementLocation = BloodPressureMeasurementLocation.unknown,
  });

  /// Create a [BloodPressureHealthValue] based on a health data point from
  /// native data format.
  factory BloodPressureHealthValue.fromHealthDataPoint(dynamic dataPoint) => BloodPressureHealthValue(
    numericValue: dataPoint['value'] as num? ?? 0,
    bodyPosition: BloodPressureBodyPosition.fromAndroidValue(dataPoint['body_position'] as int?),
    measurementLocation: BloodPressureMeasurementLocation.fromAndroidValue(dataPoint['measurement_location'] as int?),
  );

  @override
  Function get fromJsonFunction => _$BloodPressureHealthValueFromJson;
  factory BloodPressureHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<BloodPressureHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$BloodPressureHealthValueToJson(this);

  @override
  bool operator ==(Object other) =>
      other is BloodPressureHealthValue &&
      numericValue == other.numericValue &&
      bodyPosition == other.bodyPosition &&
      measurementLocation == other.measurementLocation;

  @override
  int get hashCode => Object.hash(numericValue, bodyPosition, measurementLocation);

  @override
  String toString() =>
      '$runtimeType - numericValue: $numericValue, bodyPosition: ${bodyPosition.name}, '
      'measurementLocation: ${measurementLocation.name}';
}
