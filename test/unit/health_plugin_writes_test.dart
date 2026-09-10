import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
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

  group('writeActivityIntensity', () {
    test(
      'throws on non-Android platforms',
      () {
        expect(
          () => ctx.health.writeActivityIntensity(
            intensityLevel: ActivityIntensityLevel.moderate,
            startTime: HealthFixtures.start,
            endTime: HealthFixtures.end,
          ),
          throwsA(isA<UnsupportedError>()),
        );
      },
      skip: Platform.isAndroid ? 'Not applicable on Android hosts' : null,
    );
  });

  group('writeBloodPressure', () {
    test('forwards payload', () async {
      ctx.channel.when('writeBloodPressure', true);

      final success = await ctx.health.writeBloodPressure(
        systolic: 120,
        diastolic: 80,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('writeBloodPressure');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['systolic'], 120);
      expect(args['diastolic'], 80);
    });
  });

  group('writeBloodOxygen', () {
    test('rejects invalid time range', () {
      expect(
        () => ctx.health.writeBloodOxygen(
          saturation: 0.95,
          startTime: HealthFixtures.end,
          endTime: HealthFixtures.start,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('writeMeal', () {
    test('rejects invalid time range', () {
      expect(
        () => ctx.health.writeMeal(
          mealType: MealType.LUNCH,
          startTime: HealthFixtures.end,
          endTime: HealthFixtures.start,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('forwards meal payload', () async {
      ctx.channel.when('writeMeal', true);

      final success = await ctx.health.writeMeal(
        mealType: MealType.DINNER,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        caloriesConsumed: 500,
        carbohydrates: 60,
        protein: 20,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('writeMeal');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['meal_type'], MealType.DINNER.name);
      expect(args['calories'], 500);
      expect(args['carbs'], 60);
      expect(args['protein'], 20);
    });
  });

  group('writeMenstruationFlow', () {
    test(
      'forwards flow payload',
      () async {
        ctx.channel.when('writeMenstruationFlow', true);

        final success = await ctx.health.writeMenstruationFlow(
          flow: MenstrualFlow.medium,
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
          isStartOfCycle: true,
        );

        expect(success, isTrue);
        final call = ctx.channel.lastCallFor('writeMenstruationFlow');
        expect(call, isNotNull);
        final args = Map<String, dynamic>.from(call!.arguments as Map);
        expect(args['value'], MenstrualFlow.medium.index);
        expect(args['isStartOfCycle'], isTrue);
      },
      skip: Platform.isAndroid ? 'Android uses Health Connect value mapping' : null,
    );
  });

  group('writeAudiogram', () {
    test('rejects empty arrays', () {
      expect(
        () => ctx.health.writeAudiogram(
          frequencies: const [],
          leftEarSensitivities: const [10],
          rightEarSensitivities: const [12],
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects mismatched lengths', () {
      expect(
        () => ctx.health.writeAudiogram(
          frequencies: const [1000, 2000],
          leftEarSensitivities: const [10],
          rightEarSensitivities: const [12],
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'forwards audiogram payload',
      () async {
        ctx.channel.when('writeAudiogram', true);

        final success = await ctx.health.writeAudiogram(
          frequencies: const [1000, 2000],
          leftEarSensitivities: const [10, 12],
          rightEarSensitivities: const [9, 11],
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
        );

        expect(success, isTrue);
        final call = ctx.channel.lastCallFor('writeAudiogram');
        expect(call, isNotNull);
        final args = Map<String, dynamic>.from(call!.arguments as Map);
        expect(args['frequencies'], [1000, 2000]);
      },
      skip: Platform.isAndroid ? 'Audiogram unsupported on Android' : null,
    );
  });

  group('writeInsulinDelivery', () {
    test('rejects invalid reason', () {
      expect(
        () => ctx.health.writeInsulinDelivery(
          2,
          InsulinDeliveryReason.NOT_SET,
          HealthFixtures.start,
          HealthFixtures.end,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'forwards insulin delivery payload',
      () async {
        ctx.channel.when('writeInsulinDelivery', true);

        final success = await ctx.health.writeInsulinDelivery(
          3,
          InsulinDeliveryReason.BOLUS,
          HealthFixtures.start,
          HealthFixtures.end,
        );

        expect(success, isTrue);
        final call = ctx.channel.lastCallFor('writeInsulinDelivery');
        expect(call, isNotNull);
        final args = Map<String, dynamic>.from(call!.arguments as Map);
        expect(args['units'], 3);
        expect(args['reason'], InsulinDeliveryReason.BOLUS.index);
      },
      skip: Platform.isAndroid ? 'Insulin delivery unsupported on Android' : null,
    );
  });

  group('delete APIs', () {
    test('delete forwards payload', () async {
      ctx.channel.when('delete', true);

      final success = await ctx.health.delete(
        type: HealthDataType.HEART_RATE,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('delete');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataTypeKey'], HealthDataType.HEART_RATE.name);
    });

    test('deleteByUUID rejects empty UUID', () {
      expect(
        () => ctx.health.deleteByUUID(uuid: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteByUUID forwards payload', () async {
      ctx.channel.when('deleteByUUID', true);

      final success = await ctx.health.deleteByUUID(
        uuid: 'uuid-1',
        type: HealthDataType.HEART_RATE,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('deleteByUUID');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['uuid'], 'uuid-1');
      expect(args['dataTypeKey'], HealthDataType.HEART_RATE.name);
    });

    test('deleteByClientRecordId forwards payload', () async {
      ctx.channel.when('deleteByClientRecordId', true);

      final success = await ctx.health.deleteByClientRecordId(
        dataTypeKey: HealthDataType.WEIGHT,
        clientRecordId: 'client-id',
        recordId: 'record-id',
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('deleteByClientRecordId');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataTypeKey'], HealthDataType.WEIGHT.name);
      expect(args['clientRecordId'], 'client-id');
      expect(args['recordId'], 'record-id');
    });
  });

  group('Workout routes', () {
    test('startWorkoutRoute returns identifier', () async {
      ctx.channel.when('startWorkoutRoute', 'builder-1');

      final builderId = await ctx.health.startWorkoutRoute();

      expect(builderId, 'builder-1');
      final call = ctx.channel.lastCallFor('startWorkoutRoute');
      expect(call, isNotNull);
    });

    test('insertWorkoutRouteData serializes locations', () async {
      ctx.channel.when('insertWorkoutRouteData', true);
      final location = WorkoutRouteLocation(
        latitude: 37.3349,
        longitude: -122.0090,
        timestamp: HealthFixtures.start,
        horizontalAccuracy: 5,
        verticalAccuracy: 8,
      );

      final success = await ctx.health.insertWorkoutRouteData(
        builderId: 'builder-1',
        locations: [location],
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('insertWorkoutRouteData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      final rawLocations = List<dynamic>.from(args['locations'] as List);
      final locations = rawLocations.map((entry) => Map<String, dynamic>.from(entry as Map)).toList();
      expect(locations, hasLength(1));
      expect(locations.first['latitude'], 37.3349);
      expect(locations.first['horizontalAccuracy'], 5);
    });

    test('finishWorkoutRoute returns route uuid', () async {
      ctx.channel.when('finishWorkoutRoute', {'uuid': 'route-1'});

      final routeId = await ctx.health.finishWorkoutRoute(
        builderId: 'builder-1',
        workoutUuid: 'workout-1',
        metadata: const {'note': 'test'},
      );

      expect(routeId, 'route-1');
      final call = ctx.channel.lastCallFor('finishWorkoutRoute');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['builderId'], 'builder-1');
      expect(args['workoutUUID'], 'workout-1');
      expect(args['metadata'], {'note': 'test'});
    });

    test('discardWorkoutRoute forwards builder id', () async {
      ctx.channel.when('discardWorkoutRoute', true);

      final success = await ctx.health.discardWorkoutRoute('builder-1');

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('discardWorkoutRoute');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['builderId'], 'builder-1');
    });
  });
}
