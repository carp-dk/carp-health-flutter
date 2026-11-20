part of '../../health.dart';

/// Types of insulin delivery reason
enum InsulinDeliveryReason { NOT_SET, BASAL, BOLUS }

/// A [HealthValue] object from insulin delivery (iOS only)
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class InsulinDeliveryHealthValue extends HealthValue {
  /// The amount of units of insulin taken
  double units;

  /// If it's basal, bolus or unknown reason for insulin dosage
  InsulinDeliveryReason reason;

  InsulinDeliveryHealthValue({required this.units, required this.reason});

  factory InsulinDeliveryHealthValue.fromHealthDataPoint(dynamic dataPoint) {
    final units = dataPoint['value'] as num;

    final metadata = dataPoint['metadata'] == null ? null : Map<String, dynamic>.from(dataPoint['metadata'] as Map);
    final reasonIndex = metadata == null || !metadata.containsKey('HKInsulinDeliveryReason')
        ? 0
        : metadata['HKInsulinDeliveryReason'] as double;
    final reason = InsulinDeliveryReason.values[reasonIndex.toInt()];

    return InsulinDeliveryHealthValue(units: units.toDouble(), reason: reason);
  }

  @override
  Function get fromJsonFunction => _$InsulinDeliveryHealthValueFromJson;
  factory InsulinDeliveryHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<InsulinDeliveryHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$InsulinDeliveryHealthValueToJson(this);

  @override
  bool operator ==(Object other) =>
      other is InsulinDeliveryHealthValue && units == other.units && reason == other.reason;

  @override
  int get hashCode => Object.hash(units, reason);

  @override
  String toString() => '$runtimeType - units: $units, reason: $reason';
}
