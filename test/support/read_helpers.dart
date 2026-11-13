import 'package:health/health.dart';

import 'fixtures.dart';
import 'health_test_context.dart';

/// The argument keys of the native getData method before 14.0.0.
const legacyKeys = {'dataTypeKey', 'dataUnitKey', 'startTime', 'endTime', 'recordingMethodsToFilter'};

/// Reads of the fixture range, and the getDataPage calls they make.
extension ReadHelpers on HealthTestContext {
  Future<List<HealthDataPoint>> collect(List<HealthDataType> types) =>
      health.getHealthDataFromTypes(types: types, startTime: HealthFixtures.start, endTime: HealthFixtures.end);

  Stream<HealthDataPage> pages(List<HealthDataType> types, {int? pageSize}) => health.getHealthDataPages(
    types: types,
    startTime: HealthFixtures.start,
    endTime: HealthFixtures.end,
    pageSize: pageSize,
  );

  List<Map<Object?, Object?>> pageCalls() =>
      channel.callsFor('getDataPage').map((call) => call.arguments as Map<Object?, Object?>).toList();

  /// Replies to getDataPage per data type, with the replies in [replies].
  Future<void> serve(Map<HealthDataType, List<Object?>> replies) => setUp(
    responder: (call) async {
      final reply = replies[HealthDataType.values.byName((call.arguments as Map)['dataTypeKey'] as String)]!.removeAt(
        0,
      );
      if (reply is Exception) throw reply;
      return reply;
    },
  );
}
