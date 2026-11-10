import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';

/// [minutes] after [HealthFixtures.start], the start of the hour-long swims below.
DateTime _at(int minutes) => HealthFixtures.start.add(Duration(minutes: minutes));

/// A lap from minute [from] to minute [to] of the swim, in [style].
SwimmingLap _lap(int from, int to, [SwimmingStrokeStyle style = SwimmingStrokeStyle.unknown]) =>
    SwimmingLap(startTime: _at(from), endTime: _at(to), strokeStyle: style);

/// The lap the platform gets for a lap from minute [from] to minute [to] in [style].
Map<String, Object> _sent(int from, int to, SwimmingStrokeStyle style) => {
  'startTime': _at(from).millisecondsSinceEpoch,
  'endTime': _at(to).millisecondsSinceEpoch,
  'strokeStyle': style.name,
};

/// Writing swims with their pool length, laps and stroke count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;

  setUp(() async {
    ctx = HealthTestContext();
    await ctx.setUp();
    ctx.channel.when('writeWorkoutData', true);
    ctx.channel.when('writeWorkoutDataUUID', 'workout-uuid-1');
  });

  tearDown(() async {
    await ctx.tearDown();
  });

  const methods = ['writeWorkoutData', 'writeWorkoutDataUUID'];

  /// Writes a workout of [type] over the hour from [HealthFixtures.start] to [HealthFixtures.end] with both methods,
  /// on [health] (Health Connect by default).
  Future<void> writeSwim({
    HealthWorkoutActivityType type = HealthWorkoutActivityType.SWIMMING_POOL,
    SwimmingDetails? swimming,
    int? totalSwimmingStrokeCount,
    Health? health,
  }) async {
    final writer = health ?? ctx.health;
    final success = await writer.writeWorkoutData(
      activityType: type,
      start: HealthFixtures.start,
      end: HealthFixtures.end,
      swimming: swimming,
      totalSwimmingStrokeCount: totalSwimmingStrokeCount,
    );
    expect(success, isTrue);
    final uuid = await writer.writeWorkoutDataUUID(
      activityType: type,
      start: HealthFixtures.start,
      end: HealthFixtures.end,
      swimming: swimming,
      totalSwimmingStrokeCount: totalSwimmingStrokeCount,
    );
    expect(uuid, 'workout-uuid-1');
  }

  /// The arguments that each method sent last.
  List<Map<String, dynamic>> sentArgs() => [
    for (final method in methods) Map<String, dynamic>.from(ctx.channel.lastCallFor(method)!.arguments as Map),
  ];

  group('Swimming workout writes send', () {
    test('the pool length, the laps with their stroke styles and the stroke count', () async {
      await writeSwim(
        swimming: SwimmingDetails(
          poolLength: 25,
          laps: [_lap(0, 2, SwimmingStrokeStyle.freestyle), _lap(2, 4, SwimmingStrokeStyle.kickboard), _lap(5, 7)],
        ),
        totalSwimmingStrokeCount: 96,
      );

      for (final args in sentArgs()) {
        expect(args['activityType'], HealthWorkoutActivityType.SWIMMING_POOL.name);
        expect(args['swimming'], {
          'poolLength': 25.0,
          'laps': [
            _sent(0, 2, SwimmingStrokeStyle.freestyle),
            _sent(2, 4, SwimmingStrokeStyle.kickboard),
            _sent(5, 7, SwimmingStrokeStyle.unknown),
          ],
        });
        expect((args['swimming'] as Map)['poolLength'], isA<double>());
        expect(args['totalSwimmingStrokeCount'], 96);
      }
    });

    test('every stroke style by its name', () async {
      final styles = SwimmingStrokeStyle.values;

      await writeSwim(
        swimming: SwimmingDetails(laps: [for (final (i, style) in styles.indexed) _lap(i * 5, i * 5 + 5, style)]),
      );

      for (final args in sentArgs()) {
        expect((args['swimming'] as Map)['laps'], [
          for (final (i, style) in styles.indexed) _sent(i * 5, i * 5 + 5, style),
        ]);
      }
    });

    test('an open water swim with laps and no pool length', () async {
      await writeSwim(
        type: HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
        swimming: SwimmingDetails(laps: [_lap(0, 30, SwimmingStrokeStyle.freestyle)]),
      );

      for (final args in sentArgs()) {
        expect(args['swimming'], {
          'poolLength': null,
          'laps': [_sent(0, 30, SwimmingStrokeStyle.freestyle)],
        });
        expect(args, isNot(contains('totalSwimmingStrokeCount')));
      }
    });

    test('nothing new for a pool swim without a pool length or laps, as before', () async {
      await writeSwim();

      for (final args in sentArgs()) {
        expect(args['activityType'], HealthWorkoutActivityType.SWIMMING_POOL.name);
        expect(args, isNot(contains('swimming')));
        expect(args, isNot(contains('totalSwimmingStrokeCount')));
      }
    });

    test('laps that touch each other and the ends of the workout, and a stroke count of 0', () async {
      await writeSwim(swimming: SwimmingDetails(laps: [_lap(0, 30), _lap(30, 60)]), totalSwimmingStrokeCount: 0);

      for (final args in sentArgs()) {
        expect((args['swimming'] as Map)['laps'], [
          _sent(0, 30, SwimmingStrokeStyle.unknown),
          _sent(30, 60, SwimmingStrokeStyle.unknown),
        ]);
        expect(args['totalSwimmingStrokeCount'], 0);
      }
    });

    test('a pool length of up to 1000 meters', () async {
      for (final poolLength in [0.5, 22.86, 1000.0]) {
        await writeSwim(swimming: SwimmingDetails(poolLength: poolLength));

        for (final args in sentArgs()) {
          expect(args['swimming'], {'poolLength': poolLength, 'laps': <Object>[]});
        }
      }
    });

    test('on iOS, a SWIMMING workout with laps and a stroke count', () async {
      await writeSwim(
        type: HealthWorkoutActivityType.SWIMMING,
        swimming: SwimmingDetails(laps: [_lap(0, 1, SwimmingStrokeStyle.butterfly)]),
        totalSwimmingStrokeCount: 30,
        health: HealthOnIOS(),
      );

      for (final args in sentArgs()) {
        expect(args['activityType'], HealthWorkoutActivityType.SWIMMING.name);
        expect(args['swimming'], {
          'poolLength': null,
          'laps': [_sent(0, 1, SwimmingStrokeStyle.butterfly)],
        });
        expect(args['totalSwimmingStrokeCount'], 30);
      }
    });
  });
}
