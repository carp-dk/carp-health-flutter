import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

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

  group('Permissions', () {
    test('hasPermissions throws when permissions length mismatches types', () {
      expect(
        () => ctx.health.hasPermissions(
          [HealthDataType.HEART_RATE],
          permissions: [HealthDataAccess.READ, HealthDataAccess.WRITE],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('hasPermissions forwards default permissions', () async {
      ctx.channel.when('hasPermissions', true);

      final result = await ctx.health.hasPermissions([HealthDataType.HEART_RATE, HealthDataType.WEIGHT]);

      expect(result, isTrue);
      final call = ctx.channel.lastCallFor('hasPermissions');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['types'], [HealthDataType.HEART_RATE.name, HealthDataType.WEIGHT.name]);
      expect(args['permissions'], [HealthDataAccess.READ.index, HealthDataAccess.READ.index]);
    });

    test('hasPermissions throws the error of a check that Health Connect fails', () async {
      // As when the service of the Health Connect app (Android 13 and lower) dies.
      ctx.channel.whenSequence('hasPermissions', [PlatformException(code: 'UNAVAILABLE', message: 'Binder died')]);

      await expectLater(
        ctx.health.hasPermissions([HealthDataType.WEIGHT]),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'UNAVAILABLE')),
      );
    });

    test('requestAuthorization throws when permissions length mismatches types', () {
      expect(
        () => ctx.health.requestAuthorization(
          [HealthDataType.HEART_RATE],
          permissions: [HealthDataAccess.READ, HealthDataAccess.WRITE],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('requestAuthorization rejects write access for read-only types', () {
      expect(
        () =>
            ctx.health.requestAuthorization([HealthDataType.ELECTROCARDIOGRAM], permissions: [HealthDataAccess.WRITE]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('requestAuthorization rejects write access to every type HealthKit only lets apps read', () async {
      // HealthKit raises an exception for them, which crashes the app.
      const readOnly = [
        HealthDataType.ELECTROCARDIOGRAM,
        HealthDataType.HIGH_HEART_RATE_EVENT,
        HealthDataType.LOW_HEART_RATE_EVENT,
        HealthDataType.IRREGULAR_HEART_RATE_EVENT,
        HealthDataType.WALKING_HEART_RATE,
        HealthDataType.ATRIAL_FIBRILLATION_BURDEN,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.APPLE_MOVE_TIME,
        HealthDataType.APPLE_STAND_TIME,
        HealthDataType.APPLE_STAND_HOUR,
        HealthDataType.SLEEP_WRIST_TEMPERATURE,
      ];
      for (final type in readOnly) {
        for (final access in [HealthDataAccess.WRITE, HealthDataAccess.READ_WRITE]) {
          await expectLater(
            ctx.health.requestAuthorization(
              [HealthDataType.STEPS, type],
              permissions: [HealthDataAccess.WRITE, access],
            ),
            throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains(type.name))),
            reason: '$type with $access',
          );
        }
      }
      expect(ctx.channel.calls, isEmpty);

      ctx.channel.when('requestAuthorization', true);
      final readAccess = List.filled(readOnly.length, HealthDataAccess.READ);
      expect(await ctx.health.requestAuthorization(readOnly, permissions: readAccess), isTrue);
    });

    test('requestAuthorization forwards types and permissions', () async {
      ctx.channel.when('requestAuthorization', true);

      final result = await ctx.health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );

      expect(result, isTrue);
      final call = ctx.channel.lastCallFor('requestAuthorization');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['types'], [HealthDataType.STEPS.name]);
      expect(args['permissions'], [HealthDataAccess.READ.index]);
    });

    test('revokePermissions calls channel', () async {
      await ctx.health.revokePermissions();

      final call = ctx.channel.lastCallFor('revokePermissions');
      expect(call, isNotNull);
    });
  });

  group('Availability', () {
    test('getHealthConnectSdkStatus maps native status', () async {
      ctx.channel.when('getHealthConnectSdkStatus', HealthConnectSdkStatus.sdkAvailable.nativeValue);

      final status = await ctx.health.getHealthConnectSdkStatus();

      expect(status, HealthConnectSdkStatus.sdkAvailable);
    });

    test('installHealthConnect calls channel', () async {
      await ctx.health.installHealthConnect();

      final call = ctx.channel.lastCallFor('installHealthConnect');
      expect(call, isNotNull);
    });

    test('isHealthDataHistoryAvailable returns channel value', () async {
      ctx.channel.when('isHealthDataHistoryAvailable', true);

      final available = await ctx.health.isHealthDataHistoryAvailable();

      expect(available, isTrue);
    });

    test('isHealthDataHistoryAvailable returns false when Health Connect fails', () async {
      ctx.channel.whenSequence('isHealthDataHistoryAvailable', [
        PlatformException(code: 'UNAVAILABLE', message: 'Binder died'),
      ]);

      final available = await ctx.health.isHealthDataHistoryAvailable();

      expect(available, isFalse);
    });

    test('isHealthDataHistoryAuthorized returns channel value', () async {
      ctx.channel.when('isHealthDataHistoryAuthorized', true);

      final authorized = await ctx.health.isHealthDataHistoryAuthorized();

      expect(authorized, isTrue);
    });

    test('requestHealthDataHistoryAuthorization returns channel value', () async {
      ctx.channel.when('requestHealthDataHistoryAuthorization', true);

      final authorized = await ctx.health.requestHealthDataHistoryAuthorization();

      expect(authorized, isTrue);
    });

    test('isHealthDataInBackgroundAvailable returns channel value', () async {
      ctx.channel.when('isHealthDataInBackgroundAvailable', true);

      final available = await ctx.health.isHealthDataInBackgroundAvailable();

      expect(available, isTrue);
    });

    test('isHealthDataInBackgroundAuthorized returns channel value', () async {
      ctx.channel.when('isHealthDataInBackgroundAuthorized', true);

      final authorized = await ctx.health.isHealthDataInBackgroundAuthorized();

      expect(authorized, isTrue);
    });

    test('requestHealthDataInBackgroundAuthorization returns channel value', () async {
      ctx.channel.when('requestHealthDataInBackgroundAuthorization', true);

      final authorized = await ctx.health.requestHealthDataInBackgroundAuthorization();

      expect(authorized, isTrue);
    });
  });
}
