import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/error_matchers.dart';
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

  group('Other read methods', () {
    test('getHealthIntervalDataFromTypes throws platform errors', () async {
      ctx.channel.whenSequence('getIntervalData', [PlatformException(code: 'INVALID_ARGUMENT')]);

      await expectLater(
        ctx.health.getHealthIntervalDataFromTypes(
          startDate: HealthFixtures.start,
          endDate: HealthFixtures.end,
          types: [HealthDataType.STEPS],
          interval: 60,
        ),
        throwsA(platformError('INVALID_ARGUMENT', type: HealthDataType.STEPS)),
      );
    });

    test('getHealthAggregateDataFromTypes throws platform errors', () async {
      ctx.channel.whenSequence('getAggregateData', [PlatformException(code: 'HEALTH_ERROR')]);

      await expectLater(
        ctx.health.getHealthAggregateDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startDate: HealthFixtures.start,
          endDate: HealthFixtures.end,
        ),
        throwsA(platformError('HEALTH_ERROR', type: HealthDataType.WORKOUT)),
      );
    });

    test('getHealthDataByUUID throws platform errors', () async {
      ctx.channel.whenSequence('getDataByUUID', [PlatformException(code: 'RATE_LIMIT_EXCEEDED')]);

      await expectLater(
        ctx.health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.STEPS),
        throwsA(platformError('RATE_LIMIT_EXCEEDED', type: HealthDataType.STEPS)),
      );
    });

    test('getHealthDataByUUID returns null when nothing is found', () async {
      ctx.channel.whenSequence('getDataByUUID', [null, <String, Object?>{}]);

      expect(await ctx.health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.STEPS), isNull);
      expect(await ctx.health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.SLEEP_REM), isNull);
    });

    test('getTotalStepsInInterval throws platform errors', () async {
      ctx.channel.whenSequence('getTotalStepsInInterval', [
        PlatformException(code: 'RATE_LIMIT_EXCEEDED'),
        PlatformException(code: 'STEPS_ERROR'),
      ]);

      await expectLater(
        ctx.health.getTotalStepsInInterval(HealthFixtures.start, HealthFixtures.end),
        throwsA(platformError('RATE_LIMIT_EXCEEDED', type: HealthDataType.STEPS)),
      );
      await expectLater(
        ctx.health.getTotalStepsInInterval(HealthFixtures.start, HealthFixtures.end, includeManualEntry: false),
        throwsA(platformError('STEPS_ERROR', type: HealthDataType.STEPS)),
      );
    });

    test('getChanges throws platform errors', () async {
      ctx.channel.whenSequence('getChanges', [
        PlatformException(code: 'RATE_LIMIT_EXCEEDED'),
        PlatformException(code: 'PERMISSION_DENIED'),
      ]);

      // A change carries its own data type, so the error has none.
      await expectLater(
        ctx.health.getChanges(changesToken: 'token-1'),
        throwsA(platformError('RATE_LIMIT_EXCEEDED', type: null)),
      );
      await expectLater(
        ctx.health.getChanges(changesToken: 'token-1', includeSelf: true),
        throwsA(platformError('PERMISSION_DENIED', type: null)),
      );
    });

    test('getChanges asks for a new token when the changes are too large', () async {
      ctx.channel.whenSequence('getChanges', [
        PlatformException(code: 'DATA_TOO_LARGE', message: 'Too many records in the cursor'),
      ]);

      final response = await ctx.health.getChanges(changesToken: 'token-1');

      expect(response!.changesTokenExpired, isTrue);
      expect(response.nextChangesToken, 'token-1');
      expect(response.hasMore, isFalse);
      expect(response.changes, isEmpty);
    });

    test('getChangesToken throws platform errors', () async {
      ctx.channel.whenSequence('getChangesToken', [PlatformException(code: 'RATE_LIMIT_EXCEEDED')]);

      await expectLater(
        ctx.health.getChangesToken(types: [HealthDataType.STEPS]),
        throwsA(platformError('RATE_LIMIT_EXCEEDED', type: null)),
      );
    });

    test('a missing native implementation is not wrapped', () async {
      ctx.channel.whenSequence('getIntervalData', [MissingPluginException()]);

      await expectLater(
        ctx.health.getHealthIntervalDataFromTypes(
          startDate: HealthFixtures.start,
          endDate: HealthFixtures.end,
          types: [HealthDataType.STEPS],
          interval: 60,
        ),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('Validation', () {
    final notSupported = isA<HealthException>()
        .having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)
        .having((e) => e.dataType, 'dataType', HealthDataType.ACTIVITY_INTENSITY)
        .having((e) => e.platformCode, 'platformCode', isNull)
        .having((e) => e.isRetryable, 'isRetryable', isFalse);

    test('a type not available on the platform fails before anything is read', () async {
      const types = [HealthDataType.HEART_RATE, HealthDataType.ACTIVITY_INTENSITY];

      await expectLater(ctx.collect(types), throwsA(notSupported));
      await expectLater(ctx.pages(types), emitsInOrder([emitsError(notSupported), emitsDone]));
      await expectLater(
        ctx.health.getHealthIntervalDataFromTypes(
          startDate: HealthFixtures.start,
          endDate: HealthFixtures.end,
          types: types,
          interval: 60,
        ),
        throwsA(notSupported),
      );
      expect(ctx.channel.calls, isEmpty);
    });

    test('an empty UUID is an invalid argument', () async {
      await expectLater(
        ctx.health.getHealthDataByUUID(uuid: '', type: HealthDataType.STEPS),
        throwsA(isA<HealthException>().having((e) => e.errorCode, 'errorCode', HealthErrorCode.invalidArgument)),
      );
    });
  });
}
