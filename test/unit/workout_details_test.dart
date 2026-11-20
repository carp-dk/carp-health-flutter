import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';

/// Milliseconds since the epoch of [HealthFixtures.start] plus [minutes].
int _at(int minutes) => HealthFixtures.start.add(Duration(minutes: minutes)).millisecondsSinceEpoch;

/// A workout as iOS sends it: the totals of [HealthFixtures.workoutPoint] and
/// the details of HealthDataReader+WorkoutDetails.swift.
Map<String, dynamic> _iosWorkout() => {
  ...HealthFixtures.workoutPoint(),
  'duration': 3300.0,
  'avgMets': 8.4,
  'elevationAscended': 120.5,
  'elevationDescended': 118,
  'indoorWorkout': false,
  'weatherTemperature': 21.5,
  'weatherHumidity': 64,
  'averageSpeed': 2.9,
  'maximumSpeed': 4.1,
  'workoutEvents': [
    {'type': 'pause', 'start': _at(20), 'end': _at(20)},
    {'type': 'resume', 'start': _at(25), 'end': _at(25)},
    {'type': 'lap', 'start': _at(0), 'end': _at(30)},
    {'type': 'somethingNew', 'start': _at(59), 'end': _at(59)},
  ],
};

WorkoutHealthValue _parse(Map<String, dynamic> workout) =>
    HealthDataPoint.fromHealthDataPoint(HealthDataType.WORKOUT, workout, HealthDataUnit.NO_UNIT.name).value
        as WorkoutHealthValue;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workout details', () {
    test('are parsed from an iOS workout', () {
      final workout = _parse(_iosWorkout());

      expect(workout.duration, 3300);
      expect(workout.avgMets, 8.4);
      expect((workout.elevationAscended, workout.elevationDescended), (120.5, 118));
      expect(workout.indoorWorkout, isFalse);
      expect((workout.weatherTemperature, workout.weatherHumidity), (21.5, 64));
      expect((workout.averageSpeed, workout.maximumSpeed), (2.9, 4.1));
      expect(workout.workoutEvents, [
        WorkoutEvent(type: WorkoutEventType.pause, start: _time(20), end: _time(20)),
        WorkoutEvent(type: WorkoutEventType.resume, start: _time(25), end: _time(25)),
        WorkoutEvent(type: WorkoutEventType.lap, start: _time(0), end: _time(30)),
        WorkoutEvent(type: WorkoutEventType.unknown, start: _time(59), end: _time(59)),
      ]);
      // The totals are parsed as before.
      expect((workout.totalEnergyBurned, workout.totalDistance), (200, 5000));
    });

    test('are null where the platform sends none, as on Android', () {
      final workout = _parse(HealthFixtures.workoutPoint());

      expect([
        workout.duration,
        workout.avgMets,
        workout.elevationAscended,
        workout.elevationDescended,
        workout.indoorWorkout,
        workout.weatherTemperature,
        workout.weatherHumidity,
        workout.averageSpeed,
        workout.maximumSpeed,
        workout.workoutEvents,
      ], everyElement(isNull));
    });

    test('round-trip through JSON', () {
      // Fails if lib/health.g.dart was not regenerated for the new fields.
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.WORKOUT,
        _iosWorkout(),
        HealthDataUnit.NO_UNIT.name,
      );

      final restored = HealthDataPoint.fromJson(point.toJson());

      expect(restored.value, point.value);
      expect((restored.value as WorkoutHealthValue).workoutEvents, hasLength(4));
    });

    test('take part in equality', () {
      expect(_parse(_iosWorkout()), _parse(_iosWorkout()));
      expect(_parse(_iosWorkout()).hashCode, _parse(_iosWorkout()).hashCode);
      expect(_parse({..._iosWorkout(), 'avgMets': 8.5}), isNot(_parse(_iosWorkout())));
      final otherEvents = {
        ..._iosWorkout(),
        'workoutEvents': [
          {'type': 'segment', 'start': _at(0), 'end': _at(30)},
        ],
      };
      expect(_parse(otherEvents), isNot(_parse(_iosWorkout())));
    });
  });

  group('WorkoutEvent', () {
    test('has the type names the native side sends', () {
      expect(WorkoutEventType.values.map((type) => type.name), [
        'pause',
        'resume',
        'lap',
        'marker',
        'motionPaused',
        'motionResumed',
        'segment',
        'pauseOrResumeRequest',
        'unknown',
      ]);
    });

    test('round-trips through JSON', () {
      final event = WorkoutEvent(type: WorkoutEventType.segment, start: _time(5), end: _time(15));

      final restored = WorkoutEvent.fromJson(event.toJson());

      expect(restored, event);
      expect(restored.toString(), contains('segment'));
    });
  });
}

/// [HealthFixtures.start] plus [minutes], as the parsed events have it.
DateTime _time(int minutes) => DateTime.fromMillisecondsSinceEpoch(_at(minutes));
