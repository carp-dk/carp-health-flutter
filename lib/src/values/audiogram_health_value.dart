part of '../../health.dart';

/// A [HealthValue] object for audiograms
///
/// Parameters:
/// * [frequencies] - array of frequencies of the test
/// * [leftEarSensitivities] threshold in decibel for the left ear
/// * [rightEarSensitivities] threshold in decibel for the left ear
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class AudiogramHealthValue extends HealthValue {
  /// Array of frequencies of the test.
  List<num> frequencies;

  /// Threshold in decibel for the left ear.
  List<num> leftEarSensitivities;

  /// Threshold in decibel for the right ear.
  List<num> rightEarSensitivities;

  AudiogramHealthValue({
    required this.frequencies,
    required this.leftEarSensitivities,
    required this.rightEarSensitivities,
  });

  /// Create a [AudiogramHealthValue] based on a health data point from native data format.
  factory AudiogramHealthValue.fromHealthDataPoint(dynamic dataPoint) => AudiogramHealthValue(
    frequencies: List<num>.from(dataPoint['frequencies'] as List),
    leftEarSensitivities: List<num>.from(dataPoint['leftEarSensitivities'] as List),
    rightEarSensitivities: List<num>.from(dataPoint['rightEarSensitivities'] as List),
  );

  @override
  String toString() =>
      """$runtimeType - frequencies: ${frequencies.toString()},
    left ear sensitivities: ${leftEarSensitivities.toString()},
    right ear sensitivities: ${rightEarSensitivities.toString()}""";

  @override
  Function get fromJsonFunction => _$AudiogramHealthValueFromJson;
  factory AudiogramHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<AudiogramHealthValue>(json);
  @override
  Map<String, dynamic> toJson() => _$AudiogramHealthValueToJson(this);

  @override
  bool operator ==(Object other) =>
      other is AudiogramHealthValue &&
      listEquals(frequencies, other.frequencies) &&
      listEquals(leftEarSensitivities, other.leftEarSensitivities) &&
      listEquals(rightEarSensitivities, other.rightEarSensitivities);

  @override
  int get hashCode => Object.hash(frequencies, leftEarSensitivities, rightEarSensitivities);
}
