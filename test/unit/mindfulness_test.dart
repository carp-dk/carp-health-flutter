import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_android.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = HealthFixtures.start;
  final end = HealthFixtures.end;
  const types = [HealthDataType.MINDFULNESS];

  test('MINDFULNESS is available on iOS and Android', () {
    expect(dataTypeKeysIOS, contains(HealthDataType.MINDFULNESS));
    expect(dataTypeKeysAndroid, contains(HealthDataType.MINDFULNESS));
  });

  group('MINDFULNESS on the method channel', () {
    late HealthTestContext ctx;

    setUp(() async {
      ctx = HealthTestContext();
      await ctx.setUp();
    });

    tearDown(() async {
      await ctx.tearDown();
    });

    /// Health Connect is available, and has mindfulness sessions if [mindfulness].
    void healthConnect({required bool mindfulness}) {
      ctx.channel.when('getHealthConnectSdkStatus', HealthConnectSdkStatus.sdkAvailable.nativeValue);
      ctx.channel.when('isMindfulnessSessionAvailable', mindfulness);
    }

    test('isMindfulnessSessionAvailable is what Health Connect answers on Android', () async {
      for (final mindfulness in [true, false]) {
        healthConnect(mindfulness: mindfulness);
        expect(await HealthOnAndroid().isMindfulnessSessionAvailable(), mindfulness);
      }
    });

    test('isMindfulnessSessionAvailable is false without Health Connect or when the check fails', () async {
      ctx.channel.when('getHealthConnectSdkStatus', HealthConnectSdkStatus.sdkUnavailable.nativeValue);
      expect(await HealthOnAndroid().isMindfulnessSessionAvailable(), isFalse);
      expect(ctx.channel.callsFor('isMindfulnessSessionAvailable'), isEmpty);

      ctx.channel.when('getHealthConnectSdkStatus', HealthConnectSdkStatus.sdkAvailable.nativeValue);
      ctx.channel.whenSequence('isMindfulnessSessionAvailable', [PlatformException(code: 'HEALTH_ERROR')]);
      expect(await HealthOnAndroid().isMindfulnessSessionAvailable(), isFalse);
    });

    test('isMindfulnessSessionAvailable is true on iOS, where HealthKit has mindful sessions', () async {
      expect(await HealthOnIOS().isMindfulnessSessionAvailable(), isTrue);
      expect(ctx.channel.calls, isEmpty);
    });

    test('without mindfulness sessions, Android throws notSupported before reading or writing', () async {
      healthConnect(mindfulness: false);
      final health = HealthOnAndroid();
      final notSupported = isA<HealthException>()
          .having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)
          .having((e) => e.dataType, 'dataType', HealthDataType.MINDFULNESS);

      await expectLater(
        health.getHealthDataFromTypes(types: types, startTime: start, endTime: end),
        throwsA(notSupported),
      );
      await expectLater(
        health.getHealthDataPages(types: types, startTime: start, endTime: end),
        emitsInOrder([emitsError(notSupported), emitsDone]),
      );
      await expectLater(
        health.getHealthIntervalDataFromTypes(types: types, startDate: start, endDate: end, interval: 3600),
        throwsA(notSupported),
      );
      await expectLater(
        health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.MINDFULNESS),
        throwsA(notSupported),
      );
      await expectLater(health.getChangesToken(types: types), throwsA(notSupported));
      await expectLater(
        health.writeHealthData(value: 0, type: HealthDataType.MINDFULNESS, startTime: start, endTime: end),
        throwsA(notSupported),
      );
      await expectLater(
        health.writeHealthDataUUID(value: 0, type: HealthDataType.MINDFULNESS, startTime: start, endTime: end),
        throwsA(notSupported),
      );
      expect(ctx.channel.calls.map((call) => call.method).toSet(), {
        'getHealthConnectSdkStatus',
        'isMindfulnessSessionAvailable',
      });
    });

    test('with mindfulness sessions, Android writes and reads them', () async {
      healthConnect(mindfulness: true);
      ctx.channel.when('writeData', true);
      ctx.channel.when('writeDataUUID', 'uuid-1');
      ctx.channel.when('getDataPage', HealthFixtures.page([HealthFixtures.numericPoint(value: 59)]));
      final health = HealthOnAndroid();

      expect(
        await health.writeHealthData(value: 0, type: HealthDataType.MINDFULNESS, startTime: start, endTime: end),
        isTrue,
      );
      expect(
        await health.writeHealthDataUUID(value: 0, type: HealthDataType.MINDFULNESS, startTime: start, endTime: end),
        'uuid-1',
      );
      final args = Map<String, dynamic>.from(ctx.channel.lastCallFor('writeData')!.arguments as Map);
      expect(args['dataTypeKey'], 'MINDFULNESS');
      expect(args['dataUnitKey'], HealthDataUnit.MINUTE.name);

      final points = await health.getHealthDataFromTypes(types: types, startTime: start, endTime: end);
      // The value of a session is the minutes from its start to its end, as on iOS.
      expect(points.map((point) => (point.type, point.unit, point.value)), [
        (HealthDataType.MINDFULNESS, HealthDataUnit.MINUTE, NumericHealthValue(numericValue: 60)),
      ]);
    });
  });
}
