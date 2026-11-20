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

  /// Health Connect is available, and has mindfulness sessions if [mindfulness].
  void healthConnect({bool mindfulness = true}) {
    ctx.channel.when('getHealthConnectSdkStatus', HealthConnectSdkStatus.sdkAvailable.nativeValue);
    ctx.channel.when('isMindfulnessSessionAvailable', mindfulness);
  }

  /// The arguments of the last writeData call.
  Map<String, dynamic> sent() => Map<String, dynamic>.from(ctx.channel.lastCallFor('writeData')!.arguments as Map);

  group('writeMindfulnessSession', () {
    test('has the session types of Health Connect, by name', () {
      // The Android side looks the type up by name (HealthConstants.mindfulnessSessionTypeMap).
      expect(MindfulnessSessionType.values.map((type) => type.name), [
        'UNKNOWN',
        'MEDITATION',
        'BREATHING',
        'MUSIC',
        'MOVEMENT',
        'UNGUIDED',
      ]);
    });

    test('sends the session with its type, title and notes as a MINDFULNESS writeData call', () async {
      healthConnect();
      ctx.channel.when('writeData', true);

      final success = await HealthOnAndroid().writeMindfulnessSession(
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        sessionType: MindfulnessSessionType.BREATHING,
        title: 'Morning practice',
        notes: 'Calm',
        recordingMethod: RecordingMethod.manual,
      );

      expect(success, isTrue);
      expect(ctx.channel.callsFor('writeData'), hasLength(1));
      expect(sent(), {
        'value': 60.0,
        'dataTypeKey': 'MINDFULNESS',
        'dataUnitKey': 'MINUTE',
        'startTime': HealthFixtures.start.millisecondsSinceEpoch,
        'endTime': HealthFixtures.end.millisecondsSinceEpoch,
        'recordingMethod': RecordingMethod.manual.toInt(),
        'mindfulnessSessionType': 'BREATHING',
        'title': 'Morning practice',
        'notes': 'Calm',
      });
    });

    test('sends a session of type UNKNOWN without title or notes by default', () async {
      healthConnect();
      ctx.channel.when('writeData', true);

      await HealthOnAndroid().writeMindfulnessSession(startTime: HealthFixtures.start, endTime: HealthFixtures.end);

      expect(sent(), containsPair('mindfulnessSessionType', 'UNKNOWN'));
      expect(sent(), containsPair('title', null));
      expect(sent(), containsPair('notes', null));
      expect(sent(), containsPair('recordingMethod', RecordingMethod.automatic.toInt()));
    });

    test('sends the same call on iOS, where HealthKit does not store the type, title and notes', () async {
      ctx.channel.when('writeData', true);

      final success = await HealthOnIOS().writeMindfulnessSession(
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        sessionType: MindfulnessSessionType.MEDITATION,
        title: 'Evening',
      );

      expect(success, isTrue);
      // No feature check: HealthKit has mindful sessions.
      expect(ctx.channel.calls.map((call) => call.method), ['writeData']);
      expect(sent(), containsPair('dataTypeKey', 'MINDFULNESS'));
      expect(sent(), containsPair('mindfulnessSessionType', 'MEDITATION'));
    });

    test('rejects a session that does not end after it starts, before anything is sent', () async {
      for (final health in [HealthOnAndroid(), HealthOnIOS()]) {
        for (final endTime in [HealthFixtures.start, HealthFixtures.start.subtract(const Duration(minutes: 1))]) {
          await expectLater(
            health.writeMindfulnessSession(startTime: HealthFixtures.start, endTime: endTime),
            throwsA(isA<ArgumentError>()),
          );
        }
      }
      expect(ctx.channel.calls, isEmpty);
    });

    test('rejects recording methods HealthKit does not have on iOS, before anything is sent', () async {
      for (final recordingMethod in [RecordingMethod.active, RecordingMethod.unknown]) {
        await expectLater(
          HealthOnIOS().writeMindfulnessSession(
            startTime: HealthFixtures.start,
            endTime: HealthFixtures.end,
            recordingMethod: recordingMethod,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(ctx.channel.calls, isEmpty);
    });

    test('throws notSupported without mindfulness sessions on Android, before anything is written', () async {
      healthConnect(mindfulness: false);

      await expectLater(
        HealthOnAndroid().writeMindfulnessSession(startTime: HealthFixtures.start, endTime: HealthFixtures.end),
        throwsA(
          isA<HealthException>()
              .having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)
              .having((e) => e.dataType, 'dataType', HealthDataType.MINDFULNESS),
        ),
      );
      expect(ctx.channel.callsFor('writeData'), isEmpty);
    });
  });
}
