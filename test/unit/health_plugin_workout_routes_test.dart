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

      final success = await ctx.health.insertWorkoutRouteData(builderId: 'builder-1', locations: [location]);

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
