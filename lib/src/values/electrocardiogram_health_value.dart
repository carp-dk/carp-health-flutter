part of '../../health.dart';

/// Classifications for ECG readings.
enum ElectrocardiogramClassification {
  NOT_SET,
  SINUS_RHYTHM,
  ATRIAL_FIBRILLATION,
  INCONCLUSIVE_LOW_HEART_RATE,
  INCONCLUSIVE_HIGH_HEART_RATE,
  INCONCLUSIVE_POOR_READING,
  INCONCLUSIVE_OTHER,
  UNRECOGNIZED,
}

/// Extension to assign numbers to [ElectrocardiogramClassification]s
extension ElectrocardiogramClassificationValue on ElectrocardiogramClassification {
  int get value => switch (this) {
    ElectrocardiogramClassification.NOT_SET => 0,
    ElectrocardiogramClassification.SINUS_RHYTHM => 1,
    ElectrocardiogramClassification.ATRIAL_FIBRILLATION => 2,
    ElectrocardiogramClassification.INCONCLUSIVE_LOW_HEART_RATE => 3,
    ElectrocardiogramClassification.INCONCLUSIVE_HIGH_HEART_RATE => 4,
    ElectrocardiogramClassification.INCONCLUSIVE_POOR_READING => 5,
    ElectrocardiogramClassification.INCONCLUSIVE_OTHER => 6,
    ElectrocardiogramClassification.UNRECOGNIZED => 100,
  };
}

/// A [HealthValue] object for ECGs
///
/// Parameters:
/// * [voltageValues] - an array of [ElectrocardiogramVoltageValue]s
/// * [averageHeartRate] - the average heart rate during the ECG (in BPM)
/// * [samplingFrequency] - the frequency at which the Apple Watch sampled the voltage.
/// * [classification] - an [ElectrocardiogramClassification]
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class ElectrocardiogramHealthValue extends HealthValue {
  /// An array of [ElectrocardiogramVoltageValue]s.
  List<ElectrocardiogramVoltageValue> voltageValues;

  /// The average heart rate during the ECG (in BPM).
  num? averageHeartRate;

  /// The frequency at which the Apple Watch sampled the voltage.
  double? samplingFrequency;

  /// An [ElectrocardiogramClassification].
  ElectrocardiogramClassification? classification;

  ElectrocardiogramHealthValue({
    required this.voltageValues,
    this.averageHeartRate,
    this.samplingFrequency,
    this.classification,
  });

  @override
  Function get fromJsonFunction => _$ElectrocardiogramHealthValueFromJson;
  factory ElectrocardiogramHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<ElectrocardiogramHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$ElectrocardiogramHealthValueToJson(this);

  /// Create a [ElectrocardiogramHealthValue] based on a health data point from native data format.
  factory ElectrocardiogramHealthValue.fromHealthDataPoint(dynamic dataPoint) => ElectrocardiogramHealthValue(
    voltageValues: (dataPoint['voltageValues'] as List)
        .map((voltageValue) => ElectrocardiogramVoltageValue.fromHealthDataPoint(voltageValue))
        .toList(),
    averageHeartRate: dataPoint['averageHeartRate'] as num?,
    samplingFrequency: dataPoint['samplingFrequency'] as double?,
    classification: ElectrocardiogramClassification.values.firstWhere((c) => c.value == dataPoint['classification']),
  );

  @override
  bool operator ==(Object other) =>
      other is ElectrocardiogramHealthValue &&
      voltageValues == other.voltageValues &&
      averageHeartRate == other.averageHeartRate &&
      samplingFrequency == other.samplingFrequency &&
      classification == other.classification;

  @override
  int get hashCode => Object.hash(Object.hashAll(voltageValues), averageHeartRate, samplingFrequency, classification);

  @override
  String toString() =>
      '$runtimeType - ${voltageValues.length} values, $averageHeartRate BPM, $samplingFrequency HZ, $classification';
}

/// Single voltage value belonging to a [ElectrocardiogramHealthValue]
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class ElectrocardiogramVoltageValue extends HealthValue {
  /// Voltage of the ECG.
  num voltage;

  /// Time since the start of the ECG.
  num timeSinceSampleStart;

  ElectrocardiogramVoltageValue({required this.voltage, required this.timeSinceSampleStart});

  /// Create a [ElectrocardiogramVoltageValue] based on a health data point from native data format.
  factory ElectrocardiogramVoltageValue.fromHealthDataPoint(dynamic dataPoint) => ElectrocardiogramVoltageValue(
    voltage: dataPoint['voltage'] as num,
    timeSinceSampleStart: dataPoint['timeSinceSampleStart'] as num,
  );

  @override
  Function get fromJsonFunction => _$ElectrocardiogramVoltageValueFromJson;
  factory ElectrocardiogramVoltageValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<ElectrocardiogramVoltageValue>(json);
  @override
  Map<String, dynamic> toJson() => _$ElectrocardiogramVoltageValueToJson(this);

  @override
  bool operator ==(Object other) =>
      other is ElectrocardiogramVoltageValue &&
      voltage == other.voltage &&
      timeSinceSampleStart == other.timeSinceSampleStart;

  @override
  int get hashCode => Object.hash(voltage, timeSinceSampleStart);

  @override
  String toString() => '$runtimeType - voltage: $voltage';
}
