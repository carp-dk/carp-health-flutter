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
}
