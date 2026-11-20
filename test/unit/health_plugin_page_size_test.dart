import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';
import '../support/stub_device_info.dart';

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

  group('Page size', () {
    test('must be between 1 and maxPageSize', () {
      expect(() => Health(pageSize: 0), throwsRangeError);
      expect(() => Health(pageSize: Health.maxPageSize + 1), throwsRangeError);
      expect(() => ctx.health.pageSize = 0, throwsRangeError);
      expect(() => ctx.health.pageSize = Health.maxPageSize + 1, throwsRangeError);
      expect(ctx.health.pageSize, Health.defaultPageSize);

      expect(Health(pageSize: 1).pageSize, 1);
      expect(Health(pageSize: Health.maxPageSize).pageSize, Health.maxPageSize);
    });

    test('an invalid page size for getHealthDataPages is a stream error', () async {
      await expectLater(
        ctx.pages([HealthDataType.HEART_RATE], pageSize: 0),
        emitsInOrder([emitsError(isRangeError), emitsDone]),
      );
      await expectLater(
        ctx.pages([HealthDataType.HEART_RATE], pageSize: Health.maxPageSize + 1),
        emitsError(isRangeError),
      );
      expect(ctx.channel.calls, isEmpty);
    });

    test('is forwarded to the platform', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page([]));

      ctx.health.pageSize = 123;
      await ctx.collect([HealthDataType.HEART_RATE]);
      await ctx.pages([HealthDataType.STEPS]).toList();
      await ctx.pages([HealthDataType.WEIGHT], pageSize: 7).toList();

      expect(ctx.pageCalls().map((args) => args['pageSize']), [123, 123, 7]);
      expect(ctx.health.pageSize, 123);
    });

    test('can be set in the constructor', () async {
      final health = Health(deviceInfo: StubDeviceInfoPlugin(), pageSize: 77);
      ctx.channel.when('getDataPage', HealthFixtures.page([]));

      await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(ctx.pageCalls().single['pageSize'], 77);
    });
  });
}
