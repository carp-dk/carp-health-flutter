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

    test('sends thiamin under the key both platforms read', () async {
      ctx.channel.when('writeMeal', true);

      await ctx.health.writeMeal(
        mealType: MealType.BREAKFAST,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        b1Thiamin: 0.001,
      );

      final args = Map<String, dynamic>.from(ctx.channel.lastCallFor('writeMeal')!.arguments as Map);
      // The key NutritionHealthValue reads too, so a meal reads back with its thiamin.
      expect(args['b1_thiamine'], 0.001);
      expect(args.containsKey('b1_thiamin'), isFalse);
    });
  });
}
