part of '../../health.dart';

/// The measurement location for a skin temperature record on Android.
enum SkinTemperatureMeasurementLocation {
  unknown,
  finger,
  toe,
  wrist;

  static SkinTemperatureMeasurementLocation fromAndroidValue(int? value) {
    switch (value) {
      case 1:
        return SkinTemperatureMeasurementLocation.finger;
      case 2:
        return SkinTemperatureMeasurementLocation.toe;
      case 3:
        return SkinTemperatureMeasurementLocation.wrist;
      default:
        return SkinTemperatureMeasurementLocation.unknown;
    }
  }

  int toAndroidValue() {
    switch (this) {
      case SkinTemperatureMeasurementLocation.finger:
        return 1;
      case SkinTemperatureMeasurementLocation.toe:
        return 2;
      case SkinTemperatureMeasurementLocation.wrist:
        return 3;
      case SkinTemperatureMeasurementLocation.unknown:
        return 0;
    }
  }
}

/// Represents a skin temperature delta sample on Android.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class SkinTemperatureHealthValue extends HealthValue {
  @JsonKey(name: 'temperature_delta')
  double temperatureDelta;

  double? baseline;

  @JsonKey(name: 'measurement_location')
  SkinTemperatureMeasurementLocation measurementLocation;

  SkinTemperatureHealthValue({
    required this.temperatureDelta,
    this.baseline,
    this.measurementLocation = SkinTemperatureMeasurementLocation.unknown,
  });

  /// Absolute temperature if a baseline is available.
  double? get temperature => baseline == null ? null : baseline! + temperatureDelta;

  factory SkinTemperatureHealthValue.fromHealthDataPoint(dynamic dataPoint) {
    final dataMap = Map<String, dynamic>.from(dataPoint as Map);
    final rawDelta = dataMap['temperature_delta'] ?? dataMap['value'];
    final delta = (rawDelta as num?)?.toDouble() ?? 0.0;
    final baseline = (dataMap['baseline'] as num?)?.toDouble();

    final locationRaw = dataMap['measurement_location'];
    SkinTemperatureMeasurementLocation location = SkinTemperatureMeasurementLocation.unknown;
    if (locationRaw is int) {
      location = SkinTemperatureMeasurementLocation.fromAndroidValue(locationRaw);
    } else if (locationRaw is String) {
      location = SkinTemperatureMeasurementLocation.values.firstWhere(
        (value) => value.name == locationRaw,
        orElse: () => SkinTemperatureMeasurementLocation.unknown,
      );
    }

    return SkinTemperatureHealthValue(temperatureDelta: delta, baseline: baseline, measurementLocation: location);
  }

  @override
  Function get fromJsonFunction => _$SkinTemperatureHealthValueFromJson;
  factory SkinTemperatureHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<SkinTemperatureHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$SkinTemperatureHealthValueToJson(this);

  @override
  bool operator ==(Object other) =>
      other is SkinTemperatureHealthValue &&
      temperatureDelta == other.temperatureDelta &&
      baseline == other.baseline &&
      measurementLocation == other.measurementLocation;

  @override
  int get hashCode => Object.hash(temperatureDelta, baseline, measurementLocation);

  @override
  String toString() =>
      '$runtimeType - delta: $temperatureDelta, baseline: $baseline, location: ${measurementLocation.name}';
}
