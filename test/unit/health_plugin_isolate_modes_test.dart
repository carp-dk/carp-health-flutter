import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/error_matchers.dart';
import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';
import '../support/stub_device_info.dart';

/// A device info plugin holding something that cannot be sent to another
/// isolate: if the plugin ever captured its [Health] instance in a worker
/// closure, the worker could not start.
class _UnsendableDeviceInfo extends StubDeviceInfoPlugin {
  final RawReceivePort port = RawReceivePort();
}

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

  group('Isolate modes', () {
    for (final mode in HealthIsolateMode.values) {
      test('$mode parses 2000 points the same as inline', () async {
        ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2000)));
        ctx.health.isolateMode = HealthIsolateMode.inline;
        final expected = await ctx.collect([HealthDataType.HEART_RATE]);

        ctx.health.isolateMode = mode;
        final result = await ctx.collect([HealthDataType.HEART_RATE]);
        final streamed = await ctx.pages([HealthDataType.HEART_RATE]).single;

        expect(result, hasLength(2000));
        final json = expected.map((p) => p.toJson()).toList();
        expect(result.map((p) => p.toJson()).toList(), json);
        expect(streamed.points.map((p) => p.toJson()).toList(), json);
      });
    }

    for (final mode in HealthIsolateMode.values) {
      test('$mode parses a large point read by UUID the same as inline', () async {
        // A route of 2000 locations, a reply far above 64 KiB.
        final route = HealthFixtures.workoutRoutePoint();
        route['route'] = List.filled(2000, (route['route'] as List).single);
        ctx.channel.when('getDataByUUID', route);
        Future<HealthDataPoint?> read() =>
            ctx.health.getHealthDataByUUID(uuid: 'route-uuid-1', type: HealthDataType.WORKOUT_ROUTE);

        ctx.health.isolateMode = HealthIsolateMode.inline;
        final expected = (await read())!.toJson();
        ctx.health.isolateMode = mode;
        final result = (await read())!;

        expect((result.value as WorkoutRouteHealthValue).locations, hasLength(2000));
        expect(result.sourceDeviceId, 'stub-ios-id');
        expect(result.toJson(), expected);
      });
    }

    test('a read by UUID in a worker returns null if nothing is found, and throws platform errors', () async {
      ctx.health.isolateMode = HealthIsolateMode.worker;
      ctx.channel.whenSequence('getDataByUUID', [null, <String, Object?>{}, PlatformException(code: 'UNAVAILABLE')]);
      Future<HealthDataPoint?> read() => ctx.health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.STEPS);

      expect(await read(), isNull);
      expect(await read(), isNull);
      await expectLater(read(), throwsA(platformError('UNAVAILABLE', type: HealthDataType.STEPS)));
    });

    test('the default is auto', () {
      expect(Health().isolateMode, HealthIsolateMode.auto);
      expect(Health(isolateMode: HealthIsolateMode.worker).isolateMode, HealthIsolateMode.worker);
    });

    test('a worker never receives the Health instance', () async {
      final deviceInfo = _UnsendableDeviceInfo();
      addTearDown(deviceInfo.port.close);
      final context = HealthTestContext(deviceInfo: deviceInfo, isolateMode: HealthIsolateMode.worker);
      addTearDown(context.tearDown);
      await context.setUp();
      context.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(10)));
      context.channel.when('getDataByUUID', HealthFixtures.numericPoint());

      final result = await context.health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );
      final byUuid = await context.health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.HEART_RATE);

      expect(result, hasLength(10));
      expect(result.first.sourceDeviceId, 'stub-ios-id');
      expect(byUuid!.sourceDeviceId, 'stub-ios-id');
    });

    // testWidgets never completes work done in another isolate, so these
    // would time out if a worker were used.
    testWidgets('auto parses large replies inline under flutter test', (tester) async {
      ctx.health.isolateMode = HealthIsolateMode.auto;
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2000)));

      expect(await ctx.collect([HealthDataType.HEART_RATE]), hasLength(2000));
    }, timeout: const Timeout(Duration(seconds: 20)));

    testWidgets('inline works in testWidgets', (tester) async {
      ctx.health.isolateMode = HealthIsolateMode.inline;
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2000)));

      expect(await ctx.collect([HealthDataType.HEART_RATE]), hasLength(2000));
    }, timeout: const Timeout(Duration(seconds: 20)));

    testWidgets('worker works in testWidgets with runAsync', (tester) async {
      ctx.health.isolateMode = HealthIsolateMode.worker;
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2000)));

      final result = await tester.runAsync(() => ctx.collect([HealthDataType.HEART_RATE]));

      expect(result, hasLength(2000));
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
