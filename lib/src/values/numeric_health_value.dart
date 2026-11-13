part of '../../health.dart';

/// A numerical value from Apple HealthKit or Google Health Connect
/// such as integer or double. E.g. 1, 2.9, -3
///
/// Parameters:
/// * [numericValue] - a [num] value for the [HealthDataPoint]
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class NumericHealthValue extends HealthValue {
  /// A [num] value for the [HealthDataPoint].
  num numericValue;

  NumericHealthValue({required this.numericValue});

  /// Create a [NumericHealthValue] based on a health data point from native data format.
  factory NumericHealthValue.fromHealthDataPoint(dynamic dataPoint) =>
      NumericHealthValue(numericValue: dataPoint['value'] as num? ?? 0);

  @override
  String toString() => '$runtimeType - numericValue: $numericValue';

  @override
  Function get fromJsonFunction => _$NumericHealthValueFromJson;
  factory NumericHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<NumericHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$NumericHealthValueToJson(this);

  @override
  bool operator ==(Object other) => other is NumericHealthValue && numericValue == other.numericValue;

  @override
  int get hashCode => numericValue.hashCode;
}
