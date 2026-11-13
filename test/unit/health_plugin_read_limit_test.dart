import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_android.dart';
import '../support/health_on_ios.dart';
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

  group('BODY_MASS_INDEX limit on Android', () {
    final later = HealthFixtures.start.add(const Duration(minutes: 30));

    /// Reads BMI on Android, where it is computed from a height of 1.8 m and
    /// weights of 72.9 kg and, later, 81 kg.
    Future<List<HealthDataPoint>> readBmi(int? limit) async {
      await ctx.serve({
        HealthDataType.HEIGHT: [
          HealthFixtures.page([HealthFixtures.numericPoint(uuid: 'height', value: 1.8)]),
        ],
        HealthDataType.WEIGHT: [
          HealthFixtures.page([
            HealthFixtures.numericPoint(uuid: 'w1', value: 72.9, from: HealthFixtures.start, to: HealthFixtures.start),
            HealthFixtures.numericPoint(uuid: 'w2', value: 81, from: later, to: later),
          ]),
        ],
      });
      return HealthOnAndroid().getHealthDataFromTypes(
        types: [HealthDataType.BODY_MASS_INDEX],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        limit: limit,
      );
    }

    test('reads the latest height and the newest limit weights', () async {
      final bmi = await readBmi(2);

      expect(ctx.pageCalls().map((args) => (args['dataTypeKey'], args['limit'])), [('HEIGHT', 1), ('WEIGHT', 2)]);
      // Weight / height², newest first.
      expect(bmi.map((p) => ((p.value as NumericHealthValue).numericValue * 10).round() / 10), [25.0, 22.5]);
      expect(bmi.map((p) => p.dateTo), [later, HealthFixtures.start]);
      expect(bmi.map((p) => p.type).toSet(), {HealthDataType.BODY_MASS_INDEX});
    });

    test('sends no limit without one', () async {
      final bmi = await readBmi(null);

      expect(ctx.pageCalls().map((args) => args['dataTypeKey']), ['HEIGHT', 'WEIGHT']);
      expect(ctx.pageCalls().where((args) => args.containsKey('limit')), isEmpty);
      expect(bmi, hasLength(2));
    });

    test('is read from HealthKit on iOS', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(1)));

      await HealthOnIOS().getHealthDataFromTypes(
        types: [HealthDataType.BODY_MASS_INDEX],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        limit: 2,
      );

      expect(ctx.pageCalls().map((args) => (args['dataTypeKey'], args['limit'])), [('BODY_MASS_INDEX', 2)]);
    });
  });
}
