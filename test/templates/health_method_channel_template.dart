// Copy this file into test/unit and rename to *_test.dart to activate.

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

  group('Permissions', () {
    test('hasPermissions forwards types and permissions', () async {
      ctx.channel.when('hasPermissions', true);

      final result = await ctx.health.hasPermissions(
        [HealthDataType.HEART_RATE, HealthDataType.WEIGHT],
        permissions: [HealthDataAccess.READ, HealthDataAccess.READ_WRITE],
      );

      expect(result, isTrue);
      final call = ctx.channel.lastCallFor('hasPermissions');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['types'], [HealthDataType.HEART_RATE.name, HealthDataType.WEIGHT.name]);
      expect(args['permissions'], [HealthDataAccess.READ.index, HealthDataAccess.READ_WRITE.index]);
    });

    test('requestAuthorization forwards types and permissions', () async {
      ctx.channel.when('requestAuthorization', true);

      final result = await ctx.health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );

      expect(result, isTrue);
      final call = ctx.channel.lastCallFor('requestAuthorization');
      expect(call, isNotNull);
    });
  });

  group('Reads', () {
    test('getHealthDataFromTypes parses numeric data points', () async {
      ctx.channel.when('getData', [HealthFixtures.numericPoint()]);

      final result = await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(result, hasLength(1));
      final point = result.first;
      expect(point.type, HealthDataType.HEART_RATE);
      expect(point.value, isA<NumericHealthValue>());
    });

    test('getHealthDataByUUID requests UUID and data type', () async {
      ctx.channel.when('getDataByUUID', HealthFixtures.numericPoint());

      final result = await ctx.health.getHealthDataByUUID(
        uuid: 'uuid-1',
        type: HealthDataType.HEART_RATE,
      );

      expect(result, isNotNull);
      final call = ctx.channel.lastCallFor('getDataByUUID');
      expect(call, isNotNull);
    });
  });

  group('Writes', () {
    test('writeHealthData forwards writeData payload', () async {
      ctx.channel.when('writeData', true);

      final success = await ctx.health.writeHealthData(
        value: 80,
        type: HealthDataType.HEART_RATE,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('writeData');
      expect(call, isNotNull);
    });

    test('writeWorkoutData forwards workout payload', () async {
      ctx.channel.when('writeWorkoutData', true);

      final success = await ctx.health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: HealthFixtures.start,
        end: HealthFixtures.end,
      );

      expect(success, isTrue);
      final call = ctx.channel.lastCallFor('writeWorkoutData');
      expect(call, isNotNull);
    });
  });

  group('Changes', () {
    test('getChangesToken forwards types', () async {
      ctx.channel.when('getChangesToken', 'token-1');

      final token = await ctx.health.getChangesToken(types: [HealthDataType.HEART_RATE]);

      expect(token, 'token-1');
      final call = ctx.channel.lastCallFor('getChangesToken');
      expect(call, isNotNull);
    });

    test('getChanges parses change response', () async {
      ctx.channel.when('getChanges', HealthFixtures.changesResponse());

      final response = await ctx.health.getChanges(changesToken: 'token-1');

      expect(response, isNotNull);
      expect(response!.changes, isNotEmpty);
    });
  });

  group('Workout routes', () {
    test('start/finish/discard workout route flow', () async {
      ctx.channel.when('startWorkoutRoute', 'builder-1');
      ctx.channel.when('finishWorkoutRoute', {'uuid': 'route-1'});
      ctx.channel.when('discardWorkoutRoute', true);

      final builderId = await ctx.health.startWorkoutRoute();
      expect(builderId, 'builder-1');

      final routeId = await ctx.health.finishWorkoutRoute(
        builderId: builderId,
        workoutUuid: 'workout-1',
      );
      expect(routeId, 'route-1');

      final discarded = await ctx.health.discardWorkoutRoute(builderId);
      expect(discarded, isTrue);
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
    });
  });
}
