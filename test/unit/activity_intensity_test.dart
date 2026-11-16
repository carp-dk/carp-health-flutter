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
  const types = [HealthDataType.ACTIVITY_INTENSITY];

  test('ACTIVITY_INTENSITY is available on Android only', () {
    expect(dataTypeKeysAndroid, contains(HealthDataType.ACTIVITY_INTENSITY));
    expect(dataTypeKeysIOS, isNot(contains(HealthDataType.ACTIVITY_INTENSITY)));
  });

  group('ACTIVITY_INTENSITY on the method channel', () {
    late HealthTestContext ctx;

    setUp(() async {
      ctx = HealthTestContext();
      await ctx.setUp();
    });

    tearDown(() async {
      await ctx.tearDown();
    });

    /// Health Connect is available, and has activity intensity if [activityIntensity].
    void healthConnect({required bool activityIntensity}) {
      ctx.channel.when('getHealthConnectSdkStatus', HealthConnectSdkStatus.sdkAvailable.nativeValue);
      ctx.channel.when('isActivityIntensityAvailable', activityIntensity);
    }

    Future<bool> writeActivityIntensity(Health health) => health.writeActivityIntensity(
      intensityLevel: ActivityIntensityLevel.vigorous,
      startTime: start,
      endTime: end,
      recordingMethod: RecordingMethod.manual,
      clientRecordId: 'run-1',
      clientRecordVersion: 2,
    );

    test('isActivityIntensityAvailable is what Health Connect answers on Android', () async {
      for (final activityIntensity in [true, false]) {
        healthConnect(activityIntensity: activityIntensity);
        expect(await HealthOnAndroid().isActivityIntensityAvailable(), activityIntensity);
      }
    });

    test('isActivityIntensityAvailable is false without Health Connect or when the check fails', () async {
      for (final status in [
        HealthConnectSdkStatus.sdkUnavailable,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired,
      ]) {
        ctx.channel.when('getHealthConnectSdkStatus', status.nativeValue);
        expect(await HealthOnAndroid().isActivityIntensityAvailable(), isFalse);
      }
      expect(ctx.channel.callsFor('isActivityIntensityAvailable'), isEmpty);

      ctx.channel.when('getHealthConnectSdkStatus', HealthConnectSdkStatus.sdkAvailable.nativeValue);
      ctx.channel.whenSequence('isActivityIntensityAvailable', [PlatformException(code: 'HEALTH_ERROR')]);
      expect(await HealthOnAndroid().isActivityIntensityAvailable(), isFalse);
    });

    test('isActivityIntensityAvailable is false on iOS, where HealthKit has no activity intensity', () async {
      expect(await HealthOnIOS().isActivityIntensityAvailable(), isFalse);
      expect(ctx.channel.calls, isEmpty);
    });

    test('without activity intensity, Android throws notSupported before reading, writing or tracking', () async {
      healthConnect(activityIntensity: false);
      final health = HealthOnAndroid();
      final notSupported = isA<HealthException>()
          .having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)
          .having((e) => e.dataType, 'dataType', HealthDataType.ACTIVITY_INTENSITY);

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
        health.getHealthDataByUUID(uuid: 'uuid-1', type: HealthDataType.ACTIVITY_INTENSITY),
        throwsA(notSupported),
      );
      await expectLater(health.getChangesToken(types: types), throwsA(notSupported));
      await expectLater(writeActivityIntensity(health), throwsA(notSupported));
      expect(ctx.channel.calls.map((call) => call.method).toSet(), {
        'getHealthConnectSdkStatus',
        'isActivityIntensityAvailable',
      });
    });

    test('writeHealthData rejects it as written with writeActivityIntensity, also without the feature', () async {
      healthConnect(activityIntensity: false);

      await expectLater(
        HealthOnAndroid().writeHealthData(value: 1, type: HealthDataType.ACTIVITY_INTENSITY, startTime: start),
        throwsA(isA<ArgumentError>()),
      );
      expect(ctx.channel.calls, isEmpty);
    });

    test('writeActivityIntensity checks its arguments before anything is sent, and is Android only', () async {
      healthConnect(activityIntensity: true);

      await expectLater(
        HealthOnAndroid().writeActivityIntensity(
          intensityLevel: ActivityIntensityLevel.moderate,
          startTime: end,
          endTime: start,
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        HealthOnAndroid().writeActivityIntensity(intensityLevel: ActivityIntensityLevel.unknown, startTime: start),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(writeActivityIntensity(HealthOnIOS()), throwsA(isA<UnsupportedError>()));
      expect(ctx.channel.calls, isEmpty);
    });

    test('with activity intensity, Android writes, reads and tracks it', () async {
      healthConnect(activityIntensity: true);
      ctx.channel.when('writeActivityIntensity', true);
      ctx.channel.when('getChangesToken', 'token-1');
      ctx.channel.when(
        'getDataPage',
        HealthFixtures.page([
          {...HealthFixtures.numericPoint(), 'activityIntensityType': 1},
        ]),
      );
      final health = HealthOnAndroid();

      expect(await writeActivityIntensity(health), isTrue);
      final args = Map<String, dynamic>.from(ctx.channel.lastCallFor('writeActivityIntensity')!.arguments as Map);
      expect(args, {
        'intensityType': 1,
        'startTime': start.millisecondsSinceEpoch,
        'endTime': end.millisecondsSinceEpoch,
        'recordingMethod': RecordingMethod.manual.toInt(),
        'clientRecordId': 'run-1',
        'clientRecordVersion': 2.0,
      });

      final points = await health.getHealthDataFromTypes(types: types, startTime: start, endTime: end);
      expect(points.map((point) => (point.type, point.unit, point.value)), [
        (
          HealthDataType.ACTIVITY_INTENSITY,
          HealthDataUnit.MINUTE,
          ActivityIntensityHealthValue(intensityLevel: ActivityIntensityLevel.vigorous, minutes: 60),
        ),
      ]);

      expect(await health.getChangesToken(types: types), 'token-1');
      expect((ctx.channel.lastCallFor('getChangesToken')!.arguments as Map)['types'], ['ACTIVITY_INTENSITY']);
    });
  });
}
