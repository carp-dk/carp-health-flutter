import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

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

  group('Fallback to getData', () {
    test('without getDataPage, one getData call with the 13.3.2 arguments reads everything', () async {
      ctx.channel.when('getData', HealthFixtures.points(3));

      final result = await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        recordingMethodsToFilter: [RecordingMethod.manual],
      );

      expect(result.map((p) => p.uuid), ['uuid-0', 'uuid-1', 'uuid-2']);
      expect(ctx.pageCalls(), hasLength(1));
      final getData = ctx.channel.callsFor('getData').single.arguments as Map;
      expect(getData, {
        'dataTypeKey': 'HEART_RATE',
        'dataUnitKey': HealthDataUnit.BEATS_PER_MINUTE.name,
        'startTime': HealthFixtures.start.millisecondsSinceEpoch,
        'endTime': HealthFixtures.end.millisecondsSinceEpoch,
        'recordingMethodsToFilter': [RecordingMethod.manual.toInt()],
      });
      expect(getData.keys.toSet(), legacyKeys);
    });

    test('a MissingPluginException from getDataPage falls back the same way', () async {
      ctx.channel.whenSequence('getDataPage', [MissingPluginException()]);
      ctx.channel.when('getData', HealthFixtures.points(2));

      final streamed = await ctx.pages([HealthDataType.HEART_RATE]).toList();

      expect(streamed.single.points, hasLength(2));
      expect(streamed.single.isLastPageForType, isTrue);
      expect((ctx.channel.callsFor('getData').single.arguments as Map<Object?, Object?>).keys.toSet(), legacyKeys);
    });

    test('without getDataPage and getData data, the type has no data', () async {
      expect(await ctx.collect([HealthDataType.HEART_RATE]), isEmpty);
      expect(ctx.channel.callsFor('getData'), hasLength(1));
    });

    test('a null reply after the first page fails the read', () async {
      ctx.channel.whenSequence('getDataPage', [
        HealthFixtures.page(HealthFixtures.points(1), nextPageToken: 't1'),
        null,
      ]);

      await expectLater(
        ctx.collect([HealthDataType.HEART_RATE]),
        throwsA(isA<HealthException>().having((e) => e.errorCode, 'errorCode', HealthErrorCode.unknown)),
      );
      expect(ctx.channel.callsFor('getData'), isEmpty);
    });

    test('a MissingPluginException after the first page is rethrown', () async {
      ctx.channel.whenSequence('getDataPage', [
        HealthFixtures.page(HealthFixtures.points(1), nextPageToken: 't1'),
        MissingPluginException(),
      ]);

      await expectLater(ctx.collect([HealthDataType.HEART_RATE]), throwsA(isA<MissingPluginException>()));
      expect(ctx.channel.callsFor('getData'), isEmpty);
    });

    test('a List reply holds all the data', () async {
      ctx.channel.when('getDataPage', HealthFixtures.points(3));

      final streamed = await ctx.pages([HealthDataType.HEART_RATE]).toList();

      expect(streamed.single.points, hasLength(3));
      expect(streamed.single.isLastPageForType, isTrue);
      expect(ctx.pageCalls(), hasLength(1));
      expect(ctx.channel.callsFor('getData'), isEmpty);
    });
  });
}
