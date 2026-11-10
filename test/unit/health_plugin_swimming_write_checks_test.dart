import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_android.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';

/// [minutes] after [HealthFixtures.start], the start of the hour-long swims below.
DateTime _at(int minutes) => HealthFixtures.start.add(Duration(minutes: minutes));

/// A lap from minute [from] to minute [to] of the swim.
SwimmingLap _lap(int from, int to) => SwimmingLap(startTime: _at(from), endTime: _at(to));

/// The checks of the swimming arguments of the workout writes, which throw before anything is sent.
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

  /// Expects both workout writes to throw an [ArgumentError] with [reason] in its message, and the [name] if given,
  /// for a workout of [type] over the hour from [HealthFixtures.start] to [HealthFixtures.end] on [health] (Health
  /// Connect by default), without calling the platform.
  Future<void> expectRejected(
    String reason, {
    String? name,
    HealthWorkoutActivityType type = HealthWorkoutActivityType.SWIMMING_POOL,
    SwimmingDetails? swimming,
    int? totalSwimmingStrokeCount,
    Health? health,
  }) async {
    final writer = health ?? ctx.health;
    var rejection = isA<ArgumentError>().having((e) => '${e.message}', 'message', contains(reason));
    if (name != null) rejection = rejection.having((e) => e.name, 'name', name);
    await expectLater(
      writer.writeWorkoutData(
        activityType: type,
        start: HealthFixtures.start,
        end: HealthFixtures.end,
        swimming: swimming,
        totalSwimmingStrokeCount: totalSwimmingStrokeCount,
      ),
      throwsA(rejection),
    );
    await expectLater(
      writer.writeWorkoutDataUUID(
        activityType: type,
        start: HealthFixtures.start,
        end: HealthFixtures.end,
        swimming: swimming,
        totalSwimmingStrokeCount: totalSwimmingStrokeCount,
      ),
      throwsA(rejection),
    );
    expect(ctx.channel.calls, isEmpty);
  }

  group('Swimming workout writes reject, before anything is sent,', () {
    test('swimming details for a workout that is not a swim', () async {
      for (final type in [
        HealthWorkoutActivityType.RUNNING,
        HealthWorkoutActivityType.WATER_POLO,
        HealthWorkoutActivityType.OTHER,
      ]) {
        await expectRejected(
          'Only a swim has swimming details',
          name: 'swimming',
          type: type,
          swimming: const SwimmingDetails(),
        );
      }
    });

    test('a stroke count for a workout that is not a swim, and a negative one', () async {
      await expectRejected(
        'Only a swim has a stroke count',
        name: 'totalSwimmingStrokeCount',
        type: HealthWorkoutActivityType.RUNNING,
        totalSwimmingStrokeCount: 10,
      );
      await expectRejected('Must not be negative', name: 'totalSwimmingStrokeCount', totalSwimmingStrokeCount: -1);
    });

    test('a pool length for a workout that is not a pool swim', () async {
      const swimming = SwimmingDetails(poolLength: 25);
      const reason = 'Only a SWIMMING_POOL workout has a pool length';

      await expectRejected(reason, type: HealthWorkoutActivityType.SWIMMING_OPEN_WATER, swimming: swimming);
      await expectRejected(reason, type: HealthWorkoutActivityType.SWIMMING, swimming: swimming, health: HealthOnIOS());
    });

    test('a pool length that is not more than 0 and at most 1000 meters', () async {
      for (final poolLength in [0.0, -25.0, 1000.001, double.nan, double.infinity]) {
        await expectRejected(
          'Must be more than 0 and at most 1000 meters',
          name: 'swimming.poolLength',
          swimming: SwimmingDetails(poolLength: poolLength),
        );
      }
    });

    test('a lap that does not end after it starts', () async {
      // The lap lasts less than the milliseconds the platform gets.
      final subMillisecond = SwimmingLap(startTime: _at(10), endTime: _at(10).add(const Duration(microseconds: 500)));
      for (final lap in [_lap(10, 10), _lap(20, 10), subMillisecond]) {
        await expectRejected(
          'A lap must start before it ends',
          name: 'swimming.laps[0]',
          swimming: SwimmingDetails(laps: [lap]),
        );
      }
    });

    test('a lap that is not inside the workout', () async {
      for (final lap in [_lap(-1, 5), _lap(55, 61), _lap(70, 80)]) {
        await expectRejected('A lap must be inside the workout', swimming: SwimmingDetails(laps: [lap]));
      }
    });

    test('laps that are not sorted by start time', () async {
      await expectRejected(
        'Laps must be sorted by start time',
        name: 'swimming.laps[2]',
        swimming: SwimmingDetails(laps: [_lap(0, 5), _lap(10, 20), _lap(5, 8)]),
      );
    });

    test('laps that overlap', () async {
      for (final laps in [
        [_lap(0, 10), _lap(5, 15)],
        [_lap(0, 30), _lap(10, 20)],
        [_lap(0, 10), _lap(0, 5)],
      ]) {
        await expectRejected(
          'Laps must not overlap',
          name: 'swimming.laps[1]',
          swimming: SwimmingDetails(laps: laps),
        );
      }
    });
  });

  test('Android rejects a SWIMMING workout as before, as Health Connect has no such type', () async {
    final notSupported = isA<HealthException>()
        .having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)
        .having((e) => e.dataType, 'dataType', HealthWorkoutActivityType.SWIMMING);

    final write = HealthOnAndroid().writeWorkoutData(
      activityType: HealthWorkoutActivityType.SWIMMING,
      start: HealthFixtures.start,
      end: HealthFixtures.end,
      swimming: SwimmingDetails(laps: [_lap(0, 5)]),
      totalSwimmingStrokeCount: 20,
    );

    await expectLater(write, throwsA(notSupported));
    expect(ctx.channel.calls, isEmpty);
  });
}
