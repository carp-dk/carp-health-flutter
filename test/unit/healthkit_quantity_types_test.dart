import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/error_matchers.dart';
import '../support/fixtures.dart';
import '../support/health_on_android.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

/// The HealthKit quantity types of PR #522 and their default units.
const _units = {
  HealthDataType.TIME_IN_DAYLIGHT: HealthDataUnit.MINUTE,
  HealthDataType.WALKING_DOUBLE_SUPPORT_PERCENTAGE: HealthDataUnit.PERCENT,
  HealthDataType.WALKING_STEP_LENGTH: HealthDataUnit.METER,
  HealthDataType.WALKING_ASYMMETRY_PERCENTAGE: HealthDataUnit.PERCENT,
  HealthDataType.APPLE_WALKING_STEADINESS: HealthDataUnit.PERCENT,
  HealthDataType.STAIR_ASCENT_SPEED: HealthDataUnit.METER_PER_SECOND,
  HealthDataType.STAIR_DESCENT_SPEED: HealthDataUnit.METER_PER_SECOND,
  HealthDataType.SIX_MINUTE_WALK_TEST_DISTANCE: HealthDataUnit.METER,
  HealthDataType.RUNNING_POWER: HealthDataUnit.WATT,
  HealthDataType.RUNNING_SPEED: HealthDataUnit.METER_PER_SECOND,
  HealthDataType.RUNNING_STRIDE_LENGTH: HealthDataUnit.METER,
  HealthDataType.RUNNING_VERTICAL_OSCILLATION: HealthDataUnit.METER,
  HealthDataType.RUNNING_GROUND_CONTACT_TIME: HealthDataUnit.MILLISECOND,
  HealthDataType.HEART_RATE_RECOVERY_ONE_MINUTE: HealthDataUnit.BEATS_PER_MINUTE,
  HealthDataType.PHYSICAL_EFFORT: HealthDataUnit.KILOCALORIE_PER_HOUR_KILOGRAM,
  HealthDataType.ENVIRONMENTAL_AUDIO_EXPOSURE: HealthDataUnit.DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL,
  HealthDataType.HEADPHONE_AUDIO_EXPOSURE: HealthDataUnit.DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL,
  HealthDataType.NUMBER_OF_TIMES_FALLEN: HealthDataUnit.COUNT,
  HealthDataType.BASAL_BODY_TEMPERATURE: HealthDataUnit.DEGREE_CELSIUS,
  HealthDataType.PEAK_EXPIRATORY_FLOW: HealthDataUnit.LITER_PER_MINUTE,
  HealthDataType.FORCED_VITAL_CAPACITY: HealthDataUnit.LITER,
  HealthDataType.INHALER_USAGE: HealthDataUnit.COUNT,
  HealthDataType.BLOOD_ALCOHOL_CONTENT: HealthDataUnit.PERCENT,
  HealthDataType.NUMBER_OF_ALCOHOLIC_BEVERAGES: HealthDataUnit.COUNT,
  HealthDataType.PUSH_COUNT: HealthDataUnit.COUNT,
  HealthDataType.SWIMMING_STROKE_COUNT: HealthDataUnit.COUNT,
  HealthDataType.DISTANCE_WHEELCHAIR: HealthDataUnit.METER,
  HealthDataType.DISTANCE_DOWNHILL_SNOW_SPORTS: HealthDataUnit.METER,
  HealthDataType.DISTANCE_CROSS_COUNTRY_SKIING: HealthDataUnit.METER,
  HealthDataType.DISTANCE_PADDLE_SPORTS: HealthDataUnit.METER,
  HealthDataType.DISTANCE_ROWING: HealthDataUnit.METER,
  HealthDataType.DISTANCE_SKATING_SPORTS: HealthDataUnit.METER,
  HealthDataType.CYCLING_SPEED: HealthDataUnit.METER_PER_SECOND,
  HealthDataType.CYCLING_FUNCTIONAL_THRESHOLD_POWER: HealthDataUnit.WATT,
  HealthDataType.CROSS_COUNTRY_SKIING_SPEED: HealthDataUnit.METER_PER_SECOND,
  HealthDataType.PADDLE_SPORTS_SPEED: HealthDataUnit.METER_PER_SECOND,
  HealthDataType.ROWING_SPEED: HealthDataUnit.METER_PER_SECOND,
  HealthDataType.ENVIRONMENTAL_SOUND_REDUCTION: HealthDataUnit.DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL,
  HealthDataType.WORKOUT_EFFORT_SCORE: HealthDataUnit.APPLE_EFFORT_SCORE,
  HealthDataType.ESTIMATED_WORKOUT_EFFORT_SCORE: HealthDataUnit.APPLE_EFFORT_SCORE,
  HealthDataType.APPLE_SLEEPING_BREATHING_DISTURBANCES: HealthDataUnit.COUNT,
};

/// The types HealthKit lets apps read but not write.
const _readOnly = [
  HealthDataType.ELECTROCARDIOGRAM,
  HealthDataType.HIGH_HEART_RATE_EVENT,
  HealthDataType.LOW_HEART_RATE_EVENT,
  HealthDataType.IRREGULAR_HEART_RATE_EVENT,
  HealthDataType.WALKING_HEART_RATE,
  HealthDataType.ATRIAL_FIBRILLATION_BURDEN,
  HealthDataType.APPLE_STAND_HOUR,
  HealthDataType.APPLE_MOVE_TIME,
  HealthDataType.APPLE_STAND_TIME,
  HealthDataType.EXERCISE_TIME,
  HealthDataType.SLEEP_WRIST_TEMPERATURE,
  HealthDataType.WALKING_ASYMMETRY_PERCENTAGE,
  HealthDataType.APPLE_WALKING_STEADINESS,
  HealthDataType.APPLE_SLEEPING_BREATHING_DISTURBANCES,
];

/// An hour-long interval from [HealthFixtures.start] with [value], as getIntervalData replies.
Map<String, Object?> _interval(num value) => {
  'value': value,
  'date_from': HealthFixtures.start.millisecondsSinceEpoch,
  'date_to': HealthFixtures.end.millisecondsSinceEpoch,
  'source_id': '',
  'source_name': 'com.apple.health',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthKit quantity types', () {
    test('have their own default units', () {
      for (final MapEntry(key: type, value: unit) in _units.entries) {
        expect(dataTypeToUnit[type], unit, reason: type.name);
      }
    });

    test('are available on iOS only', () {
      for (final type in _units.keys) {
        expect(dataTypeKeysIOS, contains(type));
        expect(dataTypeKeysAndroid, isNot(contains(type)));
      }
    });

    test('have new units with the names the native side uses as keys', () {
      // HealthKit looks the unit up by name.
      expect(
        [
          HealthDataUnit.LITER_PER_MINUTE,
          HealthDataUnit.KILOCALORIE_PER_HOUR_KILOGRAM,
          HealthDataUnit.APPLE_EFFORT_SCORE,
        ].map((unit) => unit.name),
        ['LITER_PER_MINUTE', 'KILOCALORIE_PER_HOUR_KILOGRAM', 'APPLE_EFFORT_SCORE'],
      );
    });

    test('round-trip through JSON', () {
      // Fails if lib/health.g.dart was not regenerated for the new enum values.
      for (final MapEntry(key: type, value: unit) in _units.entries) {
        final point = HealthDataPoint.fromHealthDataPoint(type, HealthFixtures.numericPoint(value: 7.5), unit.name);
        final restored = HealthDataPoint.fromJson(point.toJson());
        expect((restored.type, restored.unit), (type, unit));
        expect((restored.value as NumericHealthValue).numericValue, 7.5);
      }
    });
  });

  group('HealthKit quantity types on the method channel', () {
    late HealthTestContext ctx;

    setUp(() async {
      ctx = HealthTestContext();
      await ctx.setUp();
    });

    tearDown(() async {
      await ctx.tearDown();
    });

    test('are read in their units as numeric values', () async {
      await ctx.serve({
        HealthDataType.PEAK_EXPIRATORY_FLOW: [
          HealthFixtures.page([HealthFixtures.numericPoint(uuid: 'flow', value: 420)]),
        ],
        HealthDataType.PHYSICAL_EFFORT: [
          HealthFixtures.page([HealthFixtures.numericPoint(uuid: 'effort', value: 6.2)]),
        ],
        HealthDataType.WORKOUT_EFFORT_SCORE: [
          HealthFixtures.page([HealthFixtures.numericPoint(uuid: 'score', value: 7)]),
        ],
      });
      const types = [
        HealthDataType.PEAK_EXPIRATORY_FLOW,
        HealthDataType.PHYSICAL_EFFORT,
        HealthDataType.WORKOUT_EFFORT_SCORE,
      ];

      final points = await ctx.collect(types);

      expect(ctx.pageCalls().map((args) => (args['dataTypeKey'], args['dataUnitKey'])), [
        ('PEAK_EXPIRATORY_FLOW', 'LITER_PER_MINUTE'),
        ('PHYSICAL_EFFORT', 'KILOCALORIE_PER_HOUR_KILOGRAM'),
        ('WORKOUT_EFFORT_SCORE', 'APPLE_EFFORT_SCORE'),
      ]);
      expect(points.map((point) => (point.type, point.unit, point.value)), [
        (types[0], HealthDataUnit.LITER_PER_MINUTE, NumericHealthValue(numericValue: 420)),
        (types[1], HealthDataUnit.KILOCALORIE_PER_HOUR_KILOGRAM, NumericHealthValue(numericValue: 6.2)),
        (types[2], HealthDataUnit.APPLE_EFFORT_SCORE, NumericHealthValue(numericValue: 7)),
      ]);
    });

    test('have interval data: sums of cumulative types, averages of the others', () async {
      ctx.channel.whenSequence('getIntervalData', [
        [_interval(250)],
        [_interval(3.4)],
      ]);

      final points = await ctx.health.getHealthIntervalDataFromTypes(
        types: [HealthDataType.PUSH_COUNT, HealthDataType.RUNNING_SPEED],
        startDate: HealthFixtures.start,
        endDate: HealthFixtures.end,
        interval: 3600,
      );

      expect(
        ctx.channel.callsFor('getIntervalData').map((call) {
          final args = call.arguments as Map;
          return (args['dataTypeKey'], args['dataUnitKey']);
        }),
        [('PUSH_COUNT', 'COUNT'), ('RUNNING_SPEED', 'METER_PER_SECOND')],
      );
      expect(points.map((point) => (point.type, (point.value as NumericHealthValue).numericValue)), [
        (HealthDataType.PUSH_COUNT, 250),
        (HealthDataType.RUNNING_SPEED, 3.4),
      ]);
    });

    test('a read on an iOS version without the type fails with notSupported', () async {
      ctx.channel.whenSequence('getDataPage', [PlatformException(code: 'NOT_SUPPORTED')]);

      await expectLater(
        ctx.collect([HealthDataType.ROWING_SPEED]),
        throwsA(platformError('NOT_SUPPORTED', type: HealthDataType.ROWING_SPEED)),
      );
    });

    test('are not read on Android, where Health Connect does not have them', () async {
      await expectLater(
        HealthOnAndroid().getHealthDataFromTypes(
          types: [HealthDataType.PUSH_COUNT],
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
        ),
        throwsA(isA<HealthException>().having((e) => e.errorCode, 'errorCode', HealthErrorCode.notSupported)),
      );
      expect(ctx.channel.calls, isEmpty);
    });
  });

  group('Types HealthKit lets apps only read', () {
    late HealthTestContext ctx;

    setUp(() async {
      ctx = HealthTestContext();
      await ctx.setUp();
    });

    tearDown(() async {
      await ctx.tearDown();
    });

    test('write access to them is not requested: HealthKit would crash the app', () async {
      for (final type in _readOnly) {
        for (final access in [HealthDataAccess.WRITE, HealthDataAccess.READ_WRITE]) {
          await expectLater(
            ctx.health.requestAuthorization([HealthDataType.STEPS, type], permissions: [HealthDataAccess.READ, access]),
            throwsA(isA<ArgumentError>()),
            reason: '${type.name} ${access.name}',
          );
        }
      }
      expect(ctx.channel.calls, isEmpty);
    });

    test('read access to them is requested', () async {
      ctx.channel.when('requestAuthorization', true);

      expect(
        await ctx.health.requestAuthorization(
          _readOnly,
          permissions: [for (final _ in _readOnly) HealthDataAccess.READ],
        ),
        isTrue,
      );
      final args = ctx.channel.lastCallFor('requestAuthorization')!.arguments as Map;
      expect(args['types'], _readOnly.map((type) => type.name));
    });

    test('writing them on iOS throws an ArgumentError before anything is sent', () async {
      final health = HealthOnIOS();
      for (final type in _readOnly) {
        final start = HealthFixtures.start;
        final end = HealthFixtures.end;
        await expectLater(
          health.writeHealthData(value: 1, type: type, startTime: start, endTime: end),
          throwsA(isA<ArgumentError>()),
          reason: type.name,
        );
        await expectLater(
          health.writeHealthDataUUID(value: 1, type: type, startTime: start, endTime: end),
          throwsA(isA<ArgumentError>()),
          reason: type.name,
        );
      }
      expect(ctx.channel.calls, isEmpty);
    });

    test('the other new types are written in their units', () async {
      ctx.channel.when('writeData', true);

      final written = await HealthOnIOS().writeHealthData(
        value: 2,
        type: HealthDataType.INHALER_USAGE,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(written, isTrue);
      final args = ctx.channel.lastCallFor('writeData')!.arguments as Map;
      expect((args['dataTypeKey'], args['dataUnitKey'], args['value']), ('INHALER_USAGE', 'COUNT', 2.0));
    });
  });
}
