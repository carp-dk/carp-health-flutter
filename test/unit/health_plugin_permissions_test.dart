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

      final result = await ctx.health.hasPermissions(
        [HealthDataType.HEART_RATE, HealthDataType.WEIGHT],
      );

      expect(result, isTrue);
      final call = ctx.channel.lastCallFor('hasPermissions');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['types'], [HealthDataType.HEART_RATE.name, HealthDataType.WEIGHT.name]);
      expect(args['permissions'], [HealthDataAccess.READ.index, HealthDataAccess.READ.index]);
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
        () => ctx.health.requestAuthorization(
          [HealthDataType.ELECTROCARDIOGRAM],
          permissions: [HealthDataAccess.WRITE],
        ),
        throwsA(isA<ArgumentError>()),
      );
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
