import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/stub_device_info.dart';

/// The tests run on a desktop host, where the plugin takes the iOS branch.
const _deviceId = 'stub-ios-id';

/// Counts the device info lookups and fails the first [failures] of them.
class _CountingDeviceInfo extends StubDeviceInfoPlugin {
  _CountingDeviceInfo({this.failures = 0});

  int failures;
  int lookups = 0;

  Future<T> _lookUp<T>(Future<T> info) {
    lookups++;
    if (failures == 0) return info;
    failures--;
    return Future<T>.error(StateError('device info is not available'));
  }

  @override
  Future<AndroidDeviceInfo> get androidInfo => _lookUp(super.androidInfo);

  @override
  Future<IosDeviceInfo> get iosInfo => _lookUp(super.iosInfo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;

  setUp(() {
    ctx = HealthTestContext();
  });

  tearDown(() async {
    await ctx.tearDown();
  });

  Future<List<HealthDataPoint>> collect(Health health) => health.getHealthDataFromTypes(
    types: [HealthDataType.HEART_RATE],
    startTime: HealthFixtures.start,
    endTime: HealthFixtures.end,
  );

  Matcher allFromThisDevice(String id) => everyElement(
    isA<HealthDataPoint>()
        .having((p) => p.sourceDeviceId, 'sourceDeviceId', id)
        .having((p) => p.sourcePlatform, 'sourcePlatform', ctx.health.platformType),
  );

  for (final configure in [true, false]) {
    final setup = configure ? 'after configure()' : 'without configure()';

    for (final mode in HealthIsolateMode.values) {
      test('read points carry the id of this device in $mode $setup', () async {
        await ctx.setUp(configure: configure);
        ctx.health.isolateMode = mode;
        expect(ctx.health.deviceId, configure ? _deviceId : 'unknown');
        ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2000)));

        final points = await collect(ctx.health);
        final pages = await ctx.health
            .getHealthDataPages(
              types: [HealthDataType.HEART_RATE],
              startTime: HealthFixtures.start,
              endTime: HealthFixtures.end,
            )
            .toList();

        expect(points, hasLength(2000));
        expect(points, allFromThisDevice(_deviceId));
        expect(pages.single.points, allFromThisDevice(_deviceId));
        expect(ctx.health.deviceId, _deviceId);
      });
    }

    test('interval, UUID and changed points carry the id of this device $setup', () async {
      await ctx.setUp(configure: configure);
      ctx.channel.when('getIntervalData', [HealthFixtures.numericPoint()]);
      ctx.channel.when('getDataByUUID', HealthFixtures.numericPoint());
      ctx.channel.when('getChanges', HealthFixtures.changesResponse());

      final interval = await ctx.health.getHealthIntervalDataFromTypes(
        startDate: HealthFixtures.start,
        endDate: HealthFixtures.end,
        types: [HealthDataType.STEPS],
        interval: 60,
      );
      final byUuid = await ctx.health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.STEPS);
      final changes = await ctx.health.getChanges(changesToken: 'token-1');

      expect(interval, allOf(hasLength(1), allFromThisDevice(_deviceId)));
      expect([byUuid], allFromThisDevice(_deviceId));
      expect(changes!.upsertedDataPoints, allOf(hasLength(1), allFromThisDevice(_deviceId)));
    });
  }

  test('the parsing factories use the given id, or unknown', () {
    final raw = HealthFixtures.numericPoint();

    expect(HealthDataPoint.fromHealthDataPoint(HealthDataType.STEPS, raw, null).sourceDeviceId, 'unknown');
    expect(
      HealthDataPoint.fromHealthDataPoint(HealthDataType.STEPS, raw, null, sourceDeviceId: 'device-1').sourceDeviceId,
      'device-1',
    );

    final change = {'type': 'upsert', 'dataTypeKey': HealthDataType.STEPS.name, 'dataPoint': raw};
    expect(HealthChange.fromMethodChannel(change).dataPoint!.sourceDeviceId, 'unknown');
    expect(HealthChange.fromMethodChannel(change, sourceDeviceId: 'device-2').dataPoint!.sourceDeviceId, 'device-2');

    final response = HealthFixtures.changesResponse();
    expect(HealthChangesResponse.fromMethodChannel(response).upsertedDataPoints.single.sourceDeviceId, 'unknown');
    expect(
      HealthChangesResponse.fromMethodChannel(
        response,
        sourceDeviceId: 'device-3',
      ).upsertedDataPoints.single.sourceDeviceId,
      'device-3',
    );
  });

  test('the id is looked up once', () async {
    final deviceInfo = _CountingDeviceInfo();
    ctx = HealthTestContext(deviceInfo: deviceInfo);
    await ctx.setUp(configure: false);
    ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(1)));

    await collect(ctx.health);
    await collect(ctx.health);

    expect(deviceInfo.lookups, 1);
  });

  test('an id that cannot be looked up is unknown, the read still succeeds, and the next read tries again', () async {
    final deviceInfo = _CountingDeviceInfo(failures: 1);
    ctx = HealthTestContext(deviceInfo: deviceInfo);
    await ctx.setUp(configure: false);
    ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2)));

    final first = await collect(ctx.health);
    expect(first, allOf(hasLength(2), allFromThisDevice('unknown')));
    expect(ctx.health.deviceId, 'unknown');

    final second = await collect(ctx.health);
    expect(second, allOf(hasLength(2), allFromThisDevice(_deviceId)));
    expect(ctx.health.deviceId, _deviceId);
    expect(deviceInfo.lookups, 2);
  });
}
