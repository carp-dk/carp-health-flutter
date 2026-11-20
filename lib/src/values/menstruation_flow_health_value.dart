part of '../../health.dart';

enum MenstrualFlow {
  unspecified,
  none,
  light,
  medium,
  heavy,
  spotting;

  static MenstrualFlow fromHealthConnect(int value) {
    switch (value) {
      case 0:
        return MenstrualFlow.unspecified;
      case 1:
        return MenstrualFlow.light;
      case 2:
        return MenstrualFlow.medium;
      case 3:
        return MenstrualFlow.heavy;
      default:
        return MenstrualFlow.unspecified;
    }
  }

  static MenstrualFlow fromHealthKit(int value) {
    switch (value) {
      case 1:
        return MenstrualFlow.unspecified;
      case 2:
        return MenstrualFlow.light;
      case 3:
        return MenstrualFlow.medium;
      case 4:
        return MenstrualFlow.heavy;
      case 5:
        return MenstrualFlow.none;
      default:
        return MenstrualFlow.unspecified;
    }
  }

  static int toHealthConnect(MenstrualFlow value) {
    switch (value) {
      case MenstrualFlow.unspecified:
        return 0;
      case MenstrualFlow.light:
        return 1;
      case MenstrualFlow.medium:
        return 2;
      case MenstrualFlow.heavy:
        return 3;
      default:
        return -1;
    }
  }
}

/// A [HealthValue] object for menstrual flow.
///
/// Parameters:
/// * [flow] - the flow value
/// * [isStartOfCycle] - indicator whether or not this occurrence is the first day of the menstrual cycle (iOS only)
/// * [wasUserEntered] - indicator whether or not the data was entered by the user (iOS only)
/// * [dateTime] - the date and time of the menstrual flow
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class MenstruationFlowHealthValue extends HealthValue {
  final MenstrualFlow? flow;
  final bool? isStartOfCycle;
  final bool? wasUserEntered;
  final DateTime dateTime;

  MenstruationFlowHealthValue({required this.flow, required this.dateTime, this.isStartOfCycle, this.wasUserEntered});

  @override
  String toString() =>
      "flow: ${flow?.name}, startOfCycle: $isStartOfCycle, wasUserEntered: $wasUserEntered, dateTime: $dateTime";

  factory MenstruationFlowHealthValue.fromHealthDataPoint(dynamic dataPoint) {
    // Parse flow value safely
    final flowValueIndex = dataPoint['value'] as int? ?? 0;
    MenstrualFlow? menstrualFlow;
    if (Platform.isAndroid) {
      menstrualFlow = MenstrualFlow.fromHealthConnect(flowValueIndex);
    } else if (Platform.isIOS) {
      menstrualFlow = MenstrualFlow.fromHealthKit(flowValueIndex);
    }

    return MenstruationFlowHealthValue(
      flow: menstrualFlow,
      isStartOfCycle: dataPoint['metadata']?.containsKey('HKMenstrualCycleStart') == true
          ? dataPoint['metadata']['HKMenstrualCycleStart'] == 1.0
          : null,
      wasUserEntered: dataPoint['metadata']?.containsKey('HKWasUserEntered') == true
          ? dataPoint['metadata']['HKWasUserEntered'] == 1.0
          : null,
      dateTime: DateTime.fromMillisecondsSinceEpoch(dataPoint['date_from'] as int),
    );
  }

  @override
  Function get fromJsonFunction => _$MenstruationFlowHealthValueFromJson;

  factory MenstruationFlowHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<MenstruationFlowHealthValue>(json);

  @override
  Map<String, dynamic> toJson() => _$MenstruationFlowHealthValueToJson(this);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MenstruationFlowHealthValue &&
            runtimeType == other.runtimeType &&
            flow == other.flow &&
            isStartOfCycle == other.isStartOfCycle &&
            wasUserEntered == other.wasUserEntered &&
            dateTime == other.dateTime;
  }

  @override
  int get hashCode => Object.hash(flow, isStartOfCycle, wasUserEntered, dateTime);
}
