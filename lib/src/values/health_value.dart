part of '../../health.dart';

/// An abstract class for health values.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class HealthValue extends Serializable {
  HealthValue();

  @override
  Function get fromJsonFunction => _$HealthValueFromJson;
  factory HealthValue.fromJson(Map<String, dynamic> json) => FromJsonFactory().fromJson<HealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$HealthValueToJson(this);
}
