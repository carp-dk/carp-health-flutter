part of '../../health.dart';

enum ActivityIntensityLevel {
  moderate,
  vigorous,
  unknown;

  static ActivityIntensityLevel fromAndroidValue(int? value) {
    switch (value) {
      case 0:
        return ActivityIntensityLevel.moderate;
      case 1:
        return ActivityIntensityLevel.vigorous;
      default:
        return ActivityIntensityLevel.unknown;
    }
  }

  int toAndroidValue() {
    switch (this) {
      case ActivityIntensityLevel.moderate:
        return 0;
      case ActivityIntensityLevel.vigorous:
        return 1;
      case ActivityIntensityLevel.unknown:
        return -1;
    }
  }
}

/// Represents a period of moderate or vigorous activity intensity on Android.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class ActivityIntensityHealthValue extends HealthValue {
  ActivityIntensityLevel intensityLevel;
  double minutes;

  ActivityIntensityHealthValue({required this.intensityLevel, required this.minutes});

  factory ActivityIntensityHealthValue.fromHealthDataPoint(dynamic dataPoint) {
    final typeIndex = (dataPoint['activityIntensityType'] as num?)?.toInt();
    final start = dataPoint['date_from'] as int? ?? 0;
    final end = dataPoint['date_to'] as int? ?? start;
    final durationMinutes = (end - start) / (1000 * 60);

    return ActivityIntensityHealthValue(
      intensityLevel: ActivityIntensityLevel.fromAndroidValue(typeIndex),
      minutes: durationMinutes,
    );
  }

  @override
  Function get fromJsonFunction => _$ActivityIntensityHealthValueFromJson;
  factory ActivityIntensityHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<ActivityIntensityHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$ActivityIntensityHealthValueToJson(this);

  @override
  bool operator ==(Object other) =>
      other is ActivityIntensityHealthValue && intensityLevel == other.intensityLevel && minutes == other.minutes;

  @override
  int get hashCode => Object.hash(intensityLevel, minutes);

  @override
  String toString() => '$runtimeType - level: ${intensityLevel.name}, minutes: $minutes';
}
