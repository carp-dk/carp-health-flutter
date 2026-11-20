import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';

/// [minutes] after [HealthFixtures.start].
DateTime _at(int minutes) => HealthFixtures.start.add(Duration(minutes: minutes));

/// A stage of [type] from minute [from] to minute [to] after [HealthFixtures.start].
SleepSessionStage _stage(HealthDataType type, int from, int to) =>
    SleepSessionStage(type: type, startTime: _at(from), endTime: _at(to));

/// The `stages` argument the platform gets for a stage of [type] from minute [from] to minute [to].
Map<String, Object> _sent(HealthDataType type, int from, int to) => {
  'type': type.name,
  'startTime': _at(from).millisecondsSinceEpoch,
  'endTime': _at(to).millisecondsSinceEpoch,
};

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

  /// Writes a session over the hour from [HealthFixtures.start] to [HealthFixtures.end] with [stages].
  Future<bool> writeHour(
    List<SleepSessionStage> stages, {
    Health? health,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) => (health ?? ctx.health).writeSleepSession(
    startTime: HealthFixtures.start,
    endTime: HealthFixtures.end,
    stages: stages,
    recordingMethod: recordingMethod,
  );

  /// Expects [write] to throw an [ArgumentError] with [reason] in its message, without calling the platform.
  Future<void> expectRejected(Future<bool> write, String reason) async {
    await expectLater(write, throwsA(isA<ArgumentError>().having((e) => '${e.message}', 'message', contains(reason))));
    expect(ctx.channel.calls, isEmpty);
  }

  group('writeSleepSession', () {
    test('sends the session with its stages, title and notes', () async {
      ctx.channel.when('writeSleepSession', true);

      final success = await ctx.health.writeSleepSession(
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        stages: [
          _stage(HealthDataType.SLEEP_AWAKE_IN_BED, 0, 10),
          _stage(HealthDataType.SLEEP_LIGHT, 10, 30),
          _stage(HealthDataType.SLEEP_DEEP, 30, 45),
          _stage(HealthDataType.SLEEP_REM, 50, 60),
        ],
        title: 'Night',
        notes: 'Slept well',
        recordingMethod: RecordingMethod.manual,
      );

      expect(success, isTrue);
      expect(ctx.channel.calls.map((call) => call.method), ['writeSleepSession']);
      expect(ctx.channel.lastCall.arguments, {
        'startTime': HealthFixtures.start.millisecondsSinceEpoch,
        'endTime': HealthFixtures.end.millisecondsSinceEpoch,
        'title': 'Night',
        'notes': 'Slept well',
        'recordingMethod': RecordingMethod.manual.toInt(),
        'stages': [
          _sent(HealthDataType.SLEEP_AWAKE_IN_BED, 0, 10),
          _sent(HealthDataType.SLEEP_LIGHT, 10, 30),
          _sent(HealthDataType.SLEEP_DEEP, 30, 45),
          _sent(HealthDataType.SLEEP_REM, 50, 60),
        ],
      });
    });

    test('sends a session without stages, title or notes', () async {
      ctx.channel.when('writeSleepSession', true);

      expect(await writeHour(const []), isTrue);

      final args = Map<String, dynamic>.from(ctx.channel.lastCall.arguments as Map);
      expect(args['stages'], isEmpty);
      expect(args['title'], isNull);
      expect(args['notes'], isNull);
      expect(args['recordingMethod'], RecordingMethod.automatic.toInt());
    });

    test('takes every sleep stage type, in stages touching each other and the ends of the session', () async {
      ctx.channel.when('writeSleepSession', true);
      const types = [
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_AWAKE_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_OUT_OF_BED,
        HealthDataType.SLEEP_UNKNOWN,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
      ];

      // Twelve stages of five minutes fill the hour.
      expect(await writeHour([for (final (i, type) in types.indexed) _stage(type, i * 5, i * 5 + 5)]), isTrue);

      final args = Map<String, dynamic>.from(ctx.channel.lastCall.arguments as Map);
      expect(args['stages'], [for (final (i, type) in types.indexed) _sent(type, i * 5, i * 5 + 5)]);
    });

    test('returns false unless the platform says the session was saved', () async {
      ctx.channel.whenSequence('writeSleepSession', [false, null]);

      expect(await writeHour(const []), isFalse);
      expect(await writeHour(const []), isFalse);
    });

    test('takes a manual or automatic recording method on iOS', () async {
      ctx.channel.when('writeSleepSession', true);
      final health = HealthOnIOS();

      expect(await writeHour(const [], health: health, recordingMethod: RecordingMethod.manual), isTrue);
      expect(await writeHour(const [], health: health, recordingMethod: RecordingMethod.automatic), isTrue);
      expect(ctx.channel.callsFor('writeSleepSession'), hasLength(2));
    });

    test('leaves the 4-day maximum of a sleep sample to HealthKit, whose error reaches the caller', () async {
      ctx.channel.whenSequence('writeSleepSession', [PlatformException(code: 'INVALID_ARGUMENT')]);

      final write = HealthOnIOS().writeSleepSession(
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.start.add(const Duration(days: 5)),
      );

      await expectLater(write, throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGUMENT')));
      expect(ctx.channel.callsFor('writeSleepSession'), hasLength(1));
    });
  });

  group('writeSleepSession rejects, before anything is sent,', () {
    test('a session that does not end after it starts', () async {
      for (final end in [HealthFixtures.start, HealthFixtures.start.subtract(const Duration(hours: 1))]) {
        await expectRejected(
          ctx.health.writeSleepSession(startTime: HealthFixtures.start, endTime: end),
          'startTime must be before endTime',
        );
      }
    });

    test('a session shorter than the milliseconds the platform gets', () async {
      final end = HealthFixtures.start.add(const Duration(microseconds: 500));

      await expectRejected(
        ctx.health.writeSleepSession(startTime: HealthFixtures.start, endTime: end),
        'startTime must be before endTime',
      );
    });

    test('a stage of a type that is not a sleep stage', () async {
      for (final type in [HealthDataType.SLEEP_SESSION, HealthDataType.SLEEP_IN_BED, HealthDataType.HEART_RATE]) {
        await expectRejected(writeHour([_stage(type, 0, 10)]), 'Not a sleep stage type');
      }
    });

    test('a stage that does not end after it starts', () async {
      final subMillisecond = SleepSessionStage(
        type: HealthDataType.SLEEP_DEEP,
        startTime: _at(10),
        endTime: _at(10).add(const Duration(microseconds: 500)),
      );
      for (final stage in [
        _stage(HealthDataType.SLEEP_DEEP, 10, 10),
        _stage(HealthDataType.SLEEP_DEEP, 20, 10),
        subMillisecond,
      ]) {
        await expectRejected(writeHour([stage]), 'A stage must start before it ends');
      }
    });

    test('a stage that is not inside the session', () async {
      for (final stage in [
        _stage(HealthDataType.SLEEP_AWAKE_IN_BED, -5, 10),
        _stage(HealthDataType.SLEEP_AWAKE, 50, 65),
        _stage(HealthDataType.SLEEP_AWAKE, 70, 80),
      ]) {
        await expectRejected(writeHour([stage]), 'A stage must be inside the session');
      }
    });

    test('stages that are not sorted by start time', () async {
      await expectRejected(
        writeHour([_stage(HealthDataType.SLEEP_REM, 30, 40), _stage(HealthDataType.SLEEP_LIGHT, 0, 10)]),
        'Stages must be sorted by start time',
      );
    });

    test('overlapping stages', () async {
      await expectRejected(
        writeHour([_stage(HealthDataType.SLEEP_LIGHT, 0, 20), _stage(HealthDataType.SLEEP_DEEP, 10, 30)]),
        'Stages must not overlap',
      );
      await expectRejected(
        writeHour([_stage(HealthDataType.SLEEP_LIGHT, 0, 30), _stage(HealthDataType.SLEEP_AWAKE, 10, 20)]),
        'Stages must not overlap',
      );
    });

    test('a recording method other than manual or automatic on iOS', () async {
      for (final method in [RecordingMethod.active, RecordingMethod.unknown]) {
        await expectRejected(
          writeHour(const [], health: HealthOnIOS(), recordingMethod: method),
          'recordingMethod must be manual or automatic on iOS',
        );
      }
    });
  });

  group('SleepSessionStage', () {
    test('is equal to a stage of the same type and times', () {
      final stage = _stage(HealthDataType.SLEEP_REM, 0, 10);

      expect(stage, _stage(HealthDataType.SLEEP_REM, 0, 10));
      expect(stage.hashCode, _stage(HealthDataType.SLEEP_REM, 0, 10).hashCode);
      expect(stage, isNot(_stage(HealthDataType.SLEEP_DEEP, 0, 10)));
      expect(stage, isNot(_stage(HealthDataType.SLEEP_REM, 5, 10)));
      expect(stage, isNot(_stage(HealthDataType.SLEEP_REM, 0, 15)));
    });

    test('names its type and times', () {
      final text = _stage(HealthDataType.SLEEP_REM, 0, 10).toString();

      expect(text, contains('SLEEP_REM'));
      expect(text, contains('${_at(0)}'));
      expect(text, contains('${_at(10)}'));
    });
  });
}
