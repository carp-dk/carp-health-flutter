/// The state of the Menstruation flow form and its plugin call, `Health.writeMenstruationFlow`.
library;

import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/forms/common/record_options.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';
import 'package:health_example/features/write/forms/form_kit/time_span_option.dart';

import 'menstrual_flows.dart';

/// A menstrual flow to write: the flow, when it was observed, whether it starts a cycle (which only
/// HealthKit stores) and how it was recorded.
///
/// `writeMenstruationFlow` saves a Health Connect menstruation flow record on Android and a HealthKit
/// menstrual flow sample on iOS, with the cycle start flag that HealthKit requires; that flag is why
/// `writeHealthData` refuses this type on iOS. Reads return a `MENSTRUATION_FLOW` data point whose value
/// is a `MenstruationFlowHealthValue`.
class MenstruationFlowController extends WriteFormController with RecordingMethodOption {
  /// Creates the form's state: a medium flow that starts a cycle, observed now (or at [now]), written
  /// through [health] on the platform [capabilities] describe.
  MenstruationFlowController(super.health, {required this.capabilities, DateTime? now})
    : _time = TimeSpanOption.wholeMinute(now ?? DateTime.now());

  @override
  final PlatformCapabilities capabilities;

  MenstrualFlow _flow = MenstrualFlow.medium;
  bool _startOfCycle = true;
  DateTime _time;

  /// The flow (`flow`).
  MenstrualFlow get flow => _flow;
  set flow(MenstrualFlow value) => update(() => _flow = value);

  /// The flows this platform writes as themselves ([MenstrualFlows]).
  List<MenstrualFlow> get flows => MenstrualFlows.on(capabilities.platform ?? HealthPlatformType.googleHealthConnect);

  /// When the flow was observed: sent as both `startTime` and `endTime`.
  DateTime get time => _time;
  set time(DateTime value) => update(() => _time = value);

  /// Whether the flow starts a menstrual cycle (`isStartOfCycle`).
  bool get startOfCycle => _startOfCycle;
  set startOfCycle(bool value) => update(() => _startOfCycle = value);

  /// Whether the platform stores [startOfCycle]: only HealthKit does (`HKMetadataKeyMenstrualCycleStart`).
  bool get storesStartOfCycle => capabilities.isIOS;

  @override
  HealthDataType get type => HealthDataType.MENSTRUATION_FLOW;

  @override
  String get description => '${_flow.label} flow${storesStartOfCycle && _startOfCycle ? ' · start of cycle' : ''}';

  @override
  Future<WriteOutcome> performWrite() async {
    final saved = await health.writeMenstruationFlow(
      flow: _flow,
      // Both platforms store a flow as a moment: Health Connect at startTime, HealthKit at endTime. One time
      // for both keeps the record where the user put it on either platform.
      startTime: _time,
      endTime: _time,
      // Health Connect's flow records have no such flag, so the form sends it only where it is stored.
      isStartOfCycle: storesStartOfCycle && _startOfCycle,
      recordingMethod: recordingMethod,
    );
    return WriteOutcome.fromBool('writeMenstruationFlow', type, description, saved);
  }
}
