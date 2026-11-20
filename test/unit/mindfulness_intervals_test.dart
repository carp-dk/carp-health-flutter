import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;

  setUp(() async {
    ctx = HealthTestContext();
    await ctx.setUp();
  });

  tearDown(() async {
    await ctx.tearDown();
  });

  test('iOS reads the intervals of MINDFULNESS in minutes, as Android does', () async {
    final start = HealthFixtures.start;
    // As the iOS side replies: the minutes mindful sessions cover, with the apps of those sessions.
    ctx.channel.when('getIntervalData', [
      {
        'value': 25.0,
        'date_from': start.millisecondsSinceEpoch,
        'date_to': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'source_id': '',
        'source_name': 'com.example.meditation',
      },
    ]);

    final points = await HealthOnIOS().getHealthIntervalDataFromTypes(
      types: const [HealthDataType.MINDFULNESS],
      startDate: start,
      endDate: start.add(const Duration(hours: 3)),
      interval: 3600,
    );

    final call = ctx.channel.lastCallFor('getIntervalData')!;
    expect(call.arguments, containsPair('dataTypeKey', 'MINDFULNESS'));
    expect(call.arguments, containsPair('dataUnitKey', HealthDataUnit.MINUTE.name));
    expect(points.map((point) => (point.type, point.unit, point.value, point.sourceId, point.sourceName)), [
      (
        HealthDataType.MINDFULNESS,
        HealthDataUnit.MINUTE,
        NumericHealthValue(numericValue: 25),
        '',
        'com.example.meditation',
      ),
    ]);
  });

  test('an interval of several sources names them all, without one source id', () async {
    final start = HealthFixtures.start;
    // As both platforms reply for a sum or an average: the apps whose data it holds, joined.
    ctx.channel.when('getIntervalData', [
      {
        'value': 72.5,
        'date_from': start.millisecondsSinceEpoch,
        'date_to': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'source_id': '',
        'source_name': 'com.apple.health.81B4, com.example.watch',
      },
    ]);

    final point = (await HealthOnIOS().getHealthIntervalDataFromTypes(
      types: const [HealthDataType.HEART_RATE],
      startDate: start,
      endDate: start.add(const Duration(hours: 1)),
      interval: 3600,
    )).single;

    expect((point.sourceId, point.sourceName), ('', 'com.apple.health.81B4, com.example.watch'));
  });
}
