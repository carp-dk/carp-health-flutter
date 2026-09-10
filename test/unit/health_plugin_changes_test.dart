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

  group('Changes API', () {
    test('getChangesToken rejects empty types', () {
      expect(
        () => ctx.health.getChangesToken(types: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getChangesToken normalizes BMI and workout route types', () async {
      ctx.channel.when('getChangesToken', 'token-1');

      final token = await ctx.health.getChangesToken(
        types: [HealthDataType.BODY_MASS_INDEX, HealthDataType.WORKOUT_ROUTE],
      );

      expect(token, 'token-1');
      final call = ctx.channel.lastCallFor('getChangesToken');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      final types = List<String>.from(args['types'] as List);
      expect(types, isNot(contains(HealthDataType.BODY_MASS_INDEX.name)));
      expect(
        types.toSet(),
        {
          HealthDataType.WEIGHT.name,
          HealthDataType.HEIGHT.name,
          HealthDataType.WORKOUT_ROUTE.name,
          HealthDataType.WORKOUT.name,
        },
      );
    });

    test('getChanges rejects empty token', () {
      expect(
        () => ctx.health.getChanges(changesToken: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getChanges parses response', () async {
      ctx.channel.when('getChanges', HealthFixtures.changesResponse());

      final response = await ctx.health.getChanges(changesToken: 'token-1');

      expect(response, isNotNull);
      expect(response!.changes, hasLength(2));
      expect(response.upsertedDataPoints, hasLength(1));
      expect(response.deletedRecordIds, ['deleted-record-1']);
    });
  });
}
