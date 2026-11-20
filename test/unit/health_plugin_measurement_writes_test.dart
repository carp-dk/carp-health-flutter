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
        () =>
            ctx.health.writeBloodOxygen(saturation: 0.95, startTime: HealthFixtures.end, endTime: HealthFixtures.start),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('writeMenstruationFlow', () {
    test('forwards flow payload', () async {
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
    }, skip: Platform.isAndroid ? 'Android uses Health Connect value mapping' : null);
  });
}
