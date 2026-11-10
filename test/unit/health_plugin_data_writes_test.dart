import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_android.dart';
import '../support/health_on_ios.dart';
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

  group('writeHealthData', () {
    test('rejects workout type', () {
      expect(
        () => ctx.health.writeHealthData(
          value: 1,
          type: HealthDataType.WORKOUT,
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects activity intensity type', () {
      expect(
        () => ctx.health.writeHealthData(
          value: 1,
          type: HealthDataType.ACTIVITY_INTENSITY,
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects invalid time range', () {
      expect(
        () => ctx.health.writeHealthData(
          value: 1,
          type: HealthDataType.HEART_RATE,
          startTime: HealthFixtures.end,
          endTime: HealthFixtures.start,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('aligns values for sleep types and uses default unit', () async {
      ctx.channel.when('writeData', true);

      final success = await ctx.health.writeHealthData(
        value: 99,
        type: HealthDataType.SLEEP_IN_BED,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('writeData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['value'], 0);
      expect(args['dataUnitKey'], HealthDataUnit.MINUTE.name);
    });

    test('forwards data unit and recording method', () async {
      ctx.channel.when('writeData', true);

      final success = await ctx.health.writeHealthData(
        value: 80,
        type: HealthDataType.HEART_RATE,
        unit: HealthDataUnit.BEATS_PER_MINUTE,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        recordingMethod: RecordingMethod.manual,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('writeData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataUnitKey'], HealthDataUnit.BEATS_PER_MINUTE.name);
      expect(args['recordingMethod'], RecordingMethod.manual.toInt());
    });
  });

  group('writeHealthData and writeHealthDataUUID', () {
    // The test host has the iOS data types; HealthOnAndroid is Android and HealthOnIOS is iOS.
    final start = HealthFixtures.start;
    final end = HealthFixtures.end;

    /// Writes a value of [type] with both methods, expecting each to throw [matcher].
    Future<void> expectBothThrow(Health health, HealthDataType type, Matcher matcher) async {
      await expectLater(health.writeHealthData(value: 1, type: type, startTime: start, endTime: end), throwsA(matcher));
      await expectLater(
        health.writeHealthDataUUID(value: 1, type: type, startTime: start, endTime: end),
        throwsA(matcher),
      );
    }

    /// Writes a value of [type] with both methods on Android, expecting the platform to get both.
    Future<void> expectBothSent(HealthDataType type) async {
      ctx.channel.when('writeData', true);
      ctx.channel.when('writeDataUUID', 'uuid-1');
      final health = HealthOnAndroid();

      expect(await health.writeHealthData(value: 1, type: type, startTime: start, endTime: end), isTrue);
      expect(await health.writeHealthDataUUID(value: 1, type: type, startTime: start, endTime: end), 'uuid-1');
      for (final method in ['writeData', 'writeDataUUID']) {
        expect((ctx.channel.lastCallFor(method)!.arguments as Map)['dataTypeKey'], type.name);
      }
    }

    test('reject types written with a method of their own, before anything is sent', () async {
      final argumentError = isA<ArgumentError>();
      for (final health in [HealthOnAndroid(), HealthOnIOS()]) {
        await expectBothThrow(health, HealthDataType.WORKOUT, argumentError);
        await expectBothThrow(health, HealthDataType.ACTIVITY_INTENSITY, argumentError);
      }
      // HealthKit needs a delivery reason, which only writeInsulinDelivery takes.
      await expectBothThrow(HealthOnIOS(), HealthDataType.INSULIN_DELIVERY, argumentError);
      // HealthKit needs the start-of-cycle flag, which only writeMenstruationFlow takes.
      await expectBothThrow(HealthOnIOS(), HealthDataType.MENSTRUATION_FLOW, argumentError);
      expect(ctx.channel.calls, isEmpty);
    });

    test('reject INSULIN_DELIVERY on Android, where Health Connect does not have it', () async {
      expect(dataTypeKeysAndroid, isNot(contains(HealthDataType.INSULIN_DELIVERY)));
      final notSupported = isA<HealthException>()
          .having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)
          .having((e) => e.dataType, 'dataType', HealthDataType.INSULIN_DELIVERY);

      await expectBothThrow(HealthOnAndroid(), HealthDataType.INSULIN_DELIVERY, notSupported);
      expect(ctx.channel.calls, isEmpty);
    });

    test('write menstruation flow on Android, where Health Connect needs no start-of-cycle flag', () async {
      await expectBothSent(HealthDataType.MENSTRUATION_FLOW);
    });

    test('reject SLEEP_UNKNOWN on iOS, where HealthKit has no unknown sleep value', () async {
      expect(dataTypeKeysIOS, contains(HealthDataType.SLEEP_UNKNOWN));
      final notSupported = isA<HealthException>()
          .having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)
          .having((e) => e.dataType, 'dataType', HealthDataType.SLEEP_UNKNOWN);

      await expectBothThrow(HealthOnIOS(), HealthDataType.SLEEP_UNKNOWN, notSupported);
      expect(ctx.channel.calls, isEmpty);
    });

    test('write SLEEP_UNKNOWN on Android', () async {
      await expectBothSent(HealthDataType.SLEEP_UNKNOWN);
    });
  });
}
