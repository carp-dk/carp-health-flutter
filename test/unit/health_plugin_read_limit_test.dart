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

  Future<List<HealthDataPoint>> read(int? limit, [List<HealthDataType> types = const [HealthDataType.WEIGHT]]) {
    return ctx.health.getHealthDataFromTypes(
      types: types,
      startTime: HealthFixtures.start,
      endTime: HealthFixtures.end,
      limit: limit,
    );
  }

  group('getHealthDataFromTypes limit', () {
    test('forwards limit when set, newest first and in pages of at most limit points', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(1)));

      await read(1);
      await read(Health.maxPageSize);

      final calls = ctx.pageCalls();
      expect(calls.first, {
        'dataTypeKey': 'WEIGHT',
        'dataUnitKey': HealthDataUnit.KILOGRAM.name,
        'startTime': HealthFixtures.start.millisecondsSinceEpoch,
        'endTime': HealthFixtures.end.millisecondsSinceEpoch,
        'recordingMethodsToFilter': <int>[],
        'limit': 1,
        'pageSize': 1,
        'pageToken': null,
        'newestFirst': true,
      });
      expect((calls.last['limit'], calls.last['pageSize']), (Health.maxPageSize, Health.defaultPageSize));
    });

    test('omits limit when unset, and treats limit 0 as no limit', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(1)));

      await read(null);
      await read(0);

      expect(ctx.pageCalls(), hasLength(2));
      for (final args in ctx.pageCalls()) {
        expect(args.keys.toSet(), {...legacyKeys, 'pageSize', 'pageToken', 'newestFirst'});
        expect(args['pageSize'], Health.defaultPageSize);
      }
    });

    test('rejects a negative limit before anything is read', () async {
      await expectLater(read(-1), throwsArgumentError);
      expect(ctx.pageCalls(), isEmpty);
    });

    test('at most limit points come back, newest first, without a second call', () async {
      // As Health Connect replies: the samples of the record that starts last, oldest first.
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(5), nextPageToken: 't1'));

      final result = await read(2, [HealthDataType.HEART_RATE]);

      expect(result.map((p) => p.uuid), ['uuid-4', 'uuid-3']);
      expect(ctx.pageCalls(), hasLength(1));
    });

    test('pages are read until limit points are in', () async {
      // As HealthKit replies when it caps the page below the limit (ECGs and workout routes).
      ctx.channel.whenSequence('getDataPage', [
        HealthFixtures.page(HealthFixtures.points(2, offset: 4).reversed.toList(), nextPageToken: 't1'),
        HealthFixtures.page(HealthFixtures.points(2, offset: 2).reversed.toList(), nextPageToken: 't2'),
      ]);

      final result = await read(3, [HealthDataType.HEART_RATE]);

      expect(result.map((p) => p.uuid), ['uuid-5', 'uuid-4', 'uuid-3']);
      expect(ctx.pageCalls().map((args) => args['pageToken']), [null, 't1']);
    });

    test('points that end at the same time keep their order', () async {
      // HealthKit completes a page with the samples that end at its last sample's end date.
      final tied = [
        for (final uuid in ['c', 'a', 'b']) HealthFixtures.numericPoint(uuid: uuid),
      ];
      ctx.channel.when('getDataPage', HealthFixtures.page(tied, nextPageToken: 't1'));

      final result = await read(2);

      expect(result.map((p) => p.uuid), ['c', 'a']);
    });

    test('each type gets its own limit', () async {
      await ctx.serve({
        HealthDataType.STEPS: [HealthFixtures.page(HealthFixtures.points(3))],
        HealthDataType.HEART_RATE: [HealthFixtures.page(HealthFixtures.points(3, offset: 3))],
      });

      final result = await read(1, [HealthDataType.STEPS, HealthDataType.HEART_RATE]);

      expect(result.map((p) => (p.type, p.uuid)), [
        (HealthDataType.STEPS, 'uuid-2'),
        (HealthDataType.HEART_RATE, 'uuid-5'),
      ]);
    });

    test('the getData fallback gets the limit too', () async {
      ctx.channel.when('getData', HealthFixtures.points(3));

      final result = await read(2, [HealthDataType.HEART_RATE]);

      final getData = ctx.channel.callsFor('getData').single.arguments as Map<Object?, Object?>;
      expect(getData.keys.toSet(), {...legacyKeys, 'limit'});
      expect(getData['limit'], 2);
      expect(result.map((p) => p.uuid), ['uuid-2', 'uuid-1']);
    });
  });
}
