import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

/// Milliseconds since the epoch of [HealthFixtures.start] plus [minutes].
int _at(int minutes) => HealthFixtures.start.add(Duration(minutes: minutes)).millisecondsSinceEpoch;

/// [HealthFixtures.start] plus [minutes], as the parsed laps have it.
DateTime _time(int minutes) => DateTime.fromMillisecondsSinceEpoch(_at(minutes));

/// A lap from minute [from] to minute [to] in [style], as the native side sends it.
Map<String, dynamic> _sentLap(int from, int to, String style) => {
  'startTime': _at(from),
  'endTime': _at(to),
  'strokeStyle': style,
};

/// A parsed lap from minute [from] to minute [to] in [style].
SwimmingLap _lap(int from, int to, [SwimmingStrokeStyle style = SwimmingStrokeStyle.unknown]) =>
    SwimmingLap(startTime: _time(from), endTime: _time(to), strokeStyle: style);

/// A pool swim as iOS sends it: HealthKit's lap length in meters and the lap events of the workout with their stroke
/// styles, the last one recorded before watchOS 4 without a duration, besides the workout events and stroke count.
Map<String, dynamic> _iosPoolSwim() => {
  ...HealthFixtures.workoutPoint(activityType: 'SWIMMING_POOL', totalDistance: 75),
  'totalSwimmingStrokeCount': 64.0,
  'swimming': {
    'poolLength': 25.0,
    'laps': [_sentLap(0, 2, 'freestyle'), _sentLap(2, 4, 'kickboard'), _sentLap(6, 6, 'unknown')],
  },
  'workoutEvents': [
    {'type': 'lap', 'start': _at(0), 'end': _at(2)},
    {'type': 'lap', 'start': _at(2), 'end': _at(4)},
    {'type': 'lap', 'start': _at(6), 'end': _at(6)},
  ],
};

/// A pool swim as Android sends it: the laps of the Health Connect session, sorted by start time, with the length they
/// share and the stroke styles of the swimming segments over them.
Map<String, dynamic> _androidPoolSwim() => {
  ...HealthFixtures.workoutPoint(uuid: 'workout-uuid-2', activityType: 'SWIMMING_POOL', totalDistance: 100),
  'swimming': {
    'poolLength': 50.0,
    'laps': [_sentLap(0, 3, 'breaststroke'), _sentLap(3, 5, 'other')],
  },
};

WorkoutHealthValue _parse(Map<String, dynamic> workout) =>
    HealthDataPoint.fromHealthDataPoint(HealthDataType.WORKOUT, workout, HealthDataUnit.NO_UNIT.name).value
        as WorkoutHealthValue;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutHealthValue.swimming', () {
    test('is parsed from an iOS pool swim', () {
      final workout = _parse(_iosPoolSwim());

      expect(workout.workoutActivityType, HealthWorkoutActivityType.SWIMMING_POOL);
      expect(
        workout.swimming,
        SwimmingDetails(
          poolLength: 25,
          laps: [_lap(0, 2, SwimmingStrokeStyle.freestyle), _lap(2, 4, SwimmingStrokeStyle.kickboard), _lap(6, 6)],
        ),
      );
      expect(workout.totalSwimmingStrokeCount, 64);
      // The laps are workout events too, without their stroke styles.
      expect(workout.workoutEvents!.map((event) => event.type), everyElement(WorkoutEventType.lap));
    });

    test('is parsed from an Android pool swim', () {
      final workout = _parse(_androidPoolSwim());

      expect(
        workout.swimming,
        SwimmingDetails(
          poolLength: 50,
          laps: [_lap(0, 3, SwimmingStrokeStyle.breaststroke), _lap(3, 5, SwimmingStrokeStyle.other)],
        ),
      );
      expect(workout.totalSwimmingStrokeCount, isNull);
      expect(workout.workoutEvents, isNull);
    });

    test('is parsed from an open water swim, which has no pool length', () {
      final laps = [_sentLap(0, 30, 'freestyle')];
      final openWater = HealthFixtures.workoutPoint(activityType: 'SWIMMING_OPEN_WATER');

      // Both platforms send a null pool length for open water (iOS as NSNull); a map without the key parses the same.
      for (final swimming in [
        {'poolLength': null, 'laps': laps},
        {'laps': laps},
      ]) {
        final workout = _parse({...openWater, 'swimming': swimming});
        expect(workout.swimming, SwimmingDetails(laps: [_lap(0, 30, SwimmingStrokeStyle.freestyle)]));
        expect(workout.swimming!.poolLength, isNull);
      }
    });

    test('reads a stroke style this version does not know, or none, as unknown', () {
      final workout = _parse({
        ...HealthFixtures.workoutPoint(activityType: 'SWIMMING_POOL'),
        'swimming': {
          'poolLength': 25.0,
          'laps': [
            _sentLap(0, 1, 'sidestroke'),
            {'startTime': _at(1), 'endTime': _at(2)},
          ],
        },
      });

      expect(workout.swimming!.laps, [_lap(0, 1), _lap(1, 2)]);
    });

    test('takes a pool length sent as a whole number', () {
      final workout = _parse({
        ...HealthFixtures.workoutPoint(activityType: 'SWIMMING_POOL'),
        'swimming': {'poolLength': 25, 'laps': <Object>[]},
      });

      expect(workout.swimming!.poolLength, isA<double>().having((length) => length, 'poolLength', 25.0));
      expect(workout.swimming!.laps, isEmpty);
    });

    test('is null for other workouts, and for a swim with neither a pool length nor laps', () {
      expect(_parse(HealthFixtures.workoutPoint()).swimming, isNull);
      expect(_parse(HealthFixtures.workoutPoint(activityType: 'SWIMMING_POOL')).swimming, isNull);
      for (final nothing in [
        <String, dynamic>{},
        {'poolLength': null, 'laps': <Object>[]},
      ]) {
        final swim = {...HealthFixtures.workoutPoint(activityType: 'SWIMMING'), 'swimming': nothing};
        expect(_parse(swim).swimming, isNull);
      }
    });

    for (final mode in [HealthIsolateMode.inline, HealthIsolateMode.worker]) {
      test('is parsed from a read through the method channel, $mode', () async {
        final ctx = HealthTestContext(isolateMode: mode);
        await ctx.setUp();
        addTearDown(ctx.tearDown);
        ctx.channel.when('getDataPage', HealthFixtures.page([_iosPoolSwim(), _androidPoolSwim()]));

        final points = await ctx.collect([HealthDataType.WORKOUT]);

        expect(points.map((point) => (point.value as WorkoutHealthValue).swimming), [
          _parse(_iosPoolSwim()).swimming,
          _parse(_androidPoolSwim()).swimming,
        ]);
      });
    }
  });

  group('SwimmingDetails', () {
    test('round-trip through JSON with their workout', () {
      for (final swim in [_iosPoolSwim(), _androidPoolSwim()]) {
        final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.WORKOUT, swim, HealthDataUnit.NO_UNIT.name);

        final restored = HealthDataPoint.fromJson(jsonDecode(jsonEncode(point.toJson())) as Map<String, dynamic>);

        expect(restored.value, point.value);
        expect(restored.value.hashCode, point.value.hashCode);
        expect((restored.value as WorkoutHealthValue).swimming, isNotNull);
      }
    });

    test('round-trip through JSON', () {
      final utcLap = SwimmingLap(
        startTime: DateTime.utc(2025, 1, 1, 10),
        endTime: DateTime.utc(2025, 1, 1, 10, 1),
        strokeStyle: SwimmingStrokeStyle.butterfly,
      );
      final details = SwimmingDetails(poolLength: 22.86, laps: [_lap(0, 1, SwimmingStrokeStyle.mixed), utcLap]);

      final json = jsonDecode(jsonEncode(details.toJson())) as Map<String, dynamic>;

      expect(SwimmingDetails.fromJson(json), details);
      expect(json['laps'], [_lap(0, 1, SwimmingStrokeStyle.mixed).toJson(), utcLap.toJson()]);
      expect(utcLap.toJson(), {
        'startTime': '2025-01-01T10:00:00.000Z',
        'endTime': '2025-01-01T10:01:00.000Z',
        'strokeStyle': 'butterfly',
      });
      // A null pool length is left out, and missing laps are none.
      expect(const SwimmingDetails().toJson(), {'laps': <Object>[]});
      expect(SwimmingDetails.fromJson({}), const SwimmingDetails());
      expect(SwimmingLap.fromJson(utcLap.toJson()..remove('strokeStyle')).strokeStyle, SwimmingStrokeStyle.unknown);
    });

    test('equal fields make equal details with equal hash codes', () {
      // Not const, which would make them one and the same object.
      SwimmingDetails details() =>
          SwimmingDetails(poolLength: 25, laps: [_lap(0, 1, SwimmingStrokeStyle.freestyle), _lap(1, 2)]);

      expect(identical(details(), details()), isFalse);
      expect(details(), details());
      expect(details().hashCode, details().hashCode);
      expect(SwimmingDetails(), SwimmingDetails());
      expect(SwimmingDetails().hashCode, SwimmingDetails().hashCode);
    });

    test('every field takes part in equality', () {
      final variants = [
        SwimmingDetails(),
        SwimmingDetails(poolLength: 25),
        SwimmingDetails(poolLength: 50),
        SwimmingDetails(laps: [_lap(0, 1)]),
        SwimmingDetails(laps: [_lap(0, 2)]),
        SwimmingDetails(laps: [_lap(1, 2)]),
        SwimmingDetails(laps: [_lap(0, 1, SwimmingStrokeStyle.backstroke)]),
        SwimmingDetails(laps: [_lap(0, 1), _lap(1, 2)]),
        SwimmingDetails(poolLength: 25, laps: [_lap(0, 1)]),
      ];

      for (var i = 0; i < variants.length; i++) {
        for (var j = 0; j < variants.length; j++) {
          expect(variants[i] == variants[j], i == j, reason: '${variants[i]} == ${variants[j]}');
        }
      }
    });

    test('take part in the equality of their workout', () {
      expect(_parse(_iosPoolSwim()), _parse(_iosPoolSwim()));
      expect(_parse(_iosPoolSwim()).hashCode, _parse(_iosPoolSwim()).hashCode);
      final otherStyle = {
        ..._iosPoolSwim(),
        'swimming': {
          'poolLength': 25.0,
          'laps': [_sentLap(0, 2, 'backstroke'), _sentLap(2, 4, 'kickboard'), _sentLap(6, 6, 'unknown')],
        },
      };
      expect(_parse(otherStyle), isNot(_parse(_iosPoolSwim())));
      expect(_parse({..._iosPoolSwim(), 'swimming': null}), isNot(_parse(_iosPoolSwim())));
    });

    test('describe themselves', () {
      expect(
        SwimmingDetails(poolLength: 25, laps: [_lap(0, 1)]).toString(),
        'SwimmingDetails - poolLength: 25.0, laps: 1',
      );
      expect(_lap(0, 1, SwimmingStrokeStyle.kickboard).toString(), contains('strokeStyle: kickboard'));
      expect(_parse(_iosPoolSwim()).toString(), contains('swimming: SwimmingDetails - poolLength: 25.0, laps: 3'));
    });
  });

  test('SwimmingStrokeStyle has the names the native sides use', () {
    expect(SwimmingStrokeStyle.values.map((style) => style.name), [
      'unknown',
      'mixed',
      'freestyle',
      'backstroke',
      'breaststroke',
      'butterfly',
      'kickboard',
      'other',
    ]);
  });
}
