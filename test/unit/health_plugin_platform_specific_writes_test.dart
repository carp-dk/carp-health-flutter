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

    test('forwards audiogram payload', () async {
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
    }, skip: Platform.isAndroid ? 'Audiogram unsupported on Android' : null);
  });

  group('writeInsulinDelivery', () {
    test('rejects invalid reason', () {
      expect(
        () =>
            ctx.health.writeInsulinDelivery(2, InsulinDeliveryReason.NOT_SET, HealthFixtures.start, HealthFixtures.end),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('forwards insulin delivery payload', () async {
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
    }, skip: Platform.isAndroid ? 'Insulin delivery unsupported on Android' : null);
  });

  group('writeActivityIntensity', () {
    test('throws on non-Android platforms', () {
      expect(
        () => ctx.health.writeActivityIntensity(
          intensityLevel: ActivityIntensityLevel.moderate,
          startTime: HealthFixtures.start,
          endTime: HealthFixtures.end,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    }, skip: Platform.isAndroid ? 'Not applicable on Android hosts' : null);
  });
}
