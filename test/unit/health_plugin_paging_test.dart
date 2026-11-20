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

  group('getDataPage arguments', () {
    test('the first call has no token and the default page size, newest first', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(1)));

      await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        preferredUnits: {HealthDataType.HEART_RATE: HealthDataUnit.COUNT},
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        recordingMethodsToFilter: [RecordingMethod.manual],
      );

      expect(Health.defaultPageSize, 20000);
      expect(ctx.pageCalls().single, {
        'dataTypeKey': 'HEART_RATE',
        'dataUnitKey': 'COUNT',
        'startTime': HealthFixtures.start.millisecondsSinceEpoch,
        'endTime': HealthFixtures.end.millisecondsSinceEpoch,
        'recordingMethodsToFilter': [RecordingMethod.manual.toInt()],
        'pageSize': Health.defaultPageSize,
        'pageToken': null,
        'newestFirst': true,
      });
    });

    test('getHealthDataPages asks for oldest first, in the default unit', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page([]));

      await ctx.pages([HealthDataType.HEART_RATE]).toList();

      final args = ctx.pageCalls().single;
      expect(args['newestFirst'], isFalse);
      expect(args['pageToken'], isNull);
      expect(args['pageSize'], Health.defaultPageSize);
      expect(args['dataUnitKey'], HealthDataUnit.BEATS_PER_MINUTE.name);
    });

    test('only the page token changes from page to page', () async {
      ctx.channel.whenSequence('getDataPage', [
        HealthFixtures.page(HealthFixtures.points(1), nextPageToken: 'v1:1:42'),
        HealthFixtures.page(HealthFixtures.points(1, offset: 1), nextPageToken: 'v1:4:43'),
        HealthFixtures.page(HealthFixtures.points(1, offset: 2)),
      ]);

      await ctx.collect([HealthDataType.STEPS]);

      final calls = ctx.pageCalls();
      expect(calls, hasLength(3));
      for (final args in calls) {
        expect(args.keys.toSet(), {...legacyKeys, 'pageSize', 'pageToken', 'newestFirst'});
        expect(Map.of(args)..remove('pageToken'), Map.of(calls.first)..remove('pageToken'));
      }
    });
  });

  group('Paging', () {
    test('three pages come back in order and the tokens are echoed verbatim', () async {
      // Tokens are opaque: Android puts ':' inside them, iOS hex digits.
      const tokens = ['v1:1:9223372036854775807', 'v1:4:a:b:c'];
      final replies = [
        HealthFixtures.page(HealthFixtures.points(3), nextPageToken: tokens[0]),
        HealthFixtures.page(HealthFixtures.points(2, offset: 3), nextPageToken: tokens[1]),
        HealthFixtures.page(HealthFixtures.points(1, offset: 5)),
      ];
      ctx.channel.whenSequence('getDataPage', replies);

      final result = await ctx.collect([HealthDataType.HEART_RATE]);

      expect(result.map((p) => p.uuid), ['uuid-0', 'uuid-1', 'uuid-2', 'uuid-3', 'uuid-4', 'uuid-5']);
      expect(ctx.pageCalls().map((args) => args['pageToken']), [null, ...tokens]);

      ctx.channel.calls.clear();
      ctx.channel.whenSequence('getDataPage', replies);
      final streamed = await ctx.pages([HealthDataType.HEART_RATE]).toList();

      expect(streamed.map((p) => (p.points.length, p.isLastPageForType)), [(3, false), (2, false), (1, true)]);
      expect(ctx.pageCalls().map((args) => args['pageToken']), [null, ...tokens]);
    });

    test('an empty page with a token is skipped and the read goes on', () async {
      final replies = [
        HealthFixtures.page(HealthFixtures.points(2), nextPageToken: 't1'),
        HealthFixtures.page([], nextPageToken: 't2'),
        HealthFixtures.page(HealthFixtures.points(1, offset: 2)),
      ];
      ctx.channel.whenSequence('getDataPage', [...replies]);

      final streamed = await ctx.pages([HealthDataType.HEART_RATE]).toList();

      expect(streamed.map((p) => (p.points.length, p.isLastPageForType)), [(2, false), (1, true)]);
      expect(ctx.pageCalls(), hasLength(3));

      ctx.channel.whenSequence('getDataPage', [...replies]);
      expect(await ctx.collect([HealthDataType.HEART_RATE]), hasLength(3));
    });

    test('each type ends with exactly one last page, empty if it has no more data', () async {
      await ctx.serve({
        HealthDataType.HEART_RATE: [
          HealthFixtures.page(HealthFixtures.points(2), nextPageToken: 't1'),
          HealthFixtures.page([]),
        ],
        HealthDataType.STEPS: [HealthFixtures.page([])],
      });

      final streamed = await ctx.pages([HealthDataType.HEART_RATE, HealthDataType.STEPS]).toList();

      expect(streamed.map((p) => (p.type, p.points.length, p.isLastPageForType)), [
        (HealthDataType.HEART_RATE, 2, false),
        (HealthDataType.HEART_RATE, 0, true),
        (HealthDataType.STEPS, 0, true),
      ]);
      expect(streamed.map((p) => p.readPermissionDenied), everyElement(isFalse));
    });

    test('tokens restart for every type', () async {
      await ctx.serve({
        HealthDataType.HEART_RATE: [
          HealthFixtures.page(HealthFixtures.points(1), nextPageToken: 'hr-1'),
          HealthFixtures.page(HealthFixtures.points(1, offset: 1)),
        ],
        HealthDataType.STEPS: [HealthFixtures.page(HealthFixtures.points(1, offset: 2))],
      });

      await ctx.collect([HealthDataType.HEART_RATE, HealthDataType.STEPS]);

      expect(ctx.pageCalls().map((args) => (args['dataTypeKey'], args['pageToken'])), [
        ('HEART_RATE', null),
        ('HEART_RATE', 'hr-1'),
        ('STEPS', null),
      ]);
    });

    test('types are read once each, in the order first listed', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2)));

      final result = await ctx.collect([HealthDataType.STEPS, HealthDataType.HEART_RATE, HealthDataType.STEPS]);

      expect(ctx.pageCalls().map((args) => args['dataTypeKey']), ['STEPS', 'HEART_RATE']);
      expect(result.map((p) => p.type), [
        HealthDataType.STEPS,
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.HEART_RATE,
      ]);

      ctx.channel.calls.clear();
      await ctx.pages([HealthDataType.HEART_RATE, HealthDataType.HEART_RATE]).toList();
      expect(ctx.pageCalls(), hasLength(1));
    });

    test('no types read nothing', () async {
      expect(await ctx.collect([]), isEmpty);
      expect(await ctx.pages([]).toList(), isEmpty);
      expect(ctx.channel.calls.where((call) => call.method != 'getHealthConnectSdkStatus'), isEmpty);
    });

    test('duplicates within a page are removed, keeping the native order', () async {
      final points = HealthFixtures.points(3);
      ctx.channel.when('getDataPage', HealthFixtures.page([points[2], points[0], points[2], points[1]]));

      final result = await ctx.collect([HealthDataType.HEART_RATE]);

      expect(result.map((p) => p.uuid), ['uuid-2', 'uuid-0', 'uuid-1']);
    });

    test('a page token that does not advance fails the read without another call', () async {
      ctx.channel.whenSequence('getDataPage', [
        HealthFixtures.page(HealthFixtures.points(1), nextPageToken: 'same'),
        HealthFixtures.page(HealthFixtures.points(1, offset: 1), nextPageToken: 'same'),
        HealthFixtures.page([]),
      ]);

      await expectLater(
        ctx.collect([HealthDataType.HEART_RATE]),
        throwsA(
          isA<HealthException>()
              .having((e) => e.errorCode, 'errorCode', HealthErrorCode.unknown)
              .having((e) => e.dataType, 'dataType', HealthDataType.HEART_RATE),
        ),
      );
      await pumpEventQueue();
      expect(ctx.pageCalls(), hasLength(2));
    });

    test('a page token that is not a String fails the read', () async {
      ctx.channel.when('getDataPage', {'data': HealthFixtures.points(1), 'nextPageToken': 12});

      await expectLater(
        ctx.collect([HealthDataType.HEART_RATE]),
        throwsA(isA<HealthException>().having((e) => e.errorCode, 'errorCode', HealthErrorCode.unknown)),
      );
      expect(ctx.pageCalls(), hasLength(1));
    });

    test('a reply that is not a page fails the read', () async {
      for (final reply in <Object>[
        'not a page',
        {'data': 'not a list'},
      ]) {
        ctx.channel.when('getDataPage', reply);

        await expectLater(
          ctx.collect([HealthDataType.HEART_RATE]),
          throwsA(isA<HealthException>().having((e) => e.errorCode, 'errorCode', HealthErrorCode.unknown)),
        );
      }
    });
  });

  group('Read permission', () {
    test('a type without read permission is one empty last page, not an error', () async {
      await ctx.serve({
        HealthDataType.HEART_RATE: [HealthFixtures.page([], permissionDenied: true)],
        HealthDataType.STEPS: [HealthFixtures.page(HealthFixtures.points(2))],
      });

      final streamed = await ctx.pages([HealthDataType.HEART_RATE, HealthDataType.STEPS]).toList();

      expect(streamed.map((p) => (p.type, p.points.length, p.isLastPageForType, p.readPermissionDenied)), [
        (HealthDataType.HEART_RATE, 0, true, true),
        (HealthDataType.STEPS, 2, true, false),
      ]);
    });

    test('getHealthDataFromTypes returns no data for it', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page([], permissionDenied: true));

      expect(await ctx.collect([HealthDataType.HEART_RATE]), isEmpty);
    });
  });
}
