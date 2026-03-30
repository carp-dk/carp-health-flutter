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

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  group('VO2 Max – read', () {
    test('getHealthDataFromTypes returns VO2 Max data points', () async {
      ctx.channel.when('getData', [
        HealthFixtures.numericPoint(uuid: 'vo2-1', value: 42.5),
      ]);

      final result = await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.VO2_MAX],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(result, hasLength(1));
      expect(result.first.type, HealthDataType.VO2_MAX);
      expect(result.first.value, isA<NumericHealthValue>());
      expect(
        (result.first.value as NumericHealthValue).numericValue,
        42.5,
      );
    });

    test('getHealthDataFromTypes sends correct dataTypeKey for VO2 Max',
        () async {
      ctx.channel.when('getData', <dynamic>[]);

      await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.VO2_MAX],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      final call = ctx.channel.lastCallFor('getData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataTypeKey'], HealthDataType.VO2_MAX.name);
    });

    test(
        'getHealthDataFromTypes uses MILLILITER_PER_KILOGRAM_PER_MINUTE as default unit',
        () async {
      ctx.channel.when('getData', <dynamic>[]);

      await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.VO2_MAX],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      final call = ctx.channel.lastCallFor('getData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(
        args['dataUnitKey'],
        HealthDataUnit.MILLILITER_PER_KILOGRAM_PER_MINUTE.name,
      );
    });

    test('getHealthDataFromTypes returns empty list when no VO2 Max data',
        () async {
      ctx.channel.when('getData', <dynamic>[]);

      final result = await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.VO2_MAX],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(result, isEmpty);
    });

    test('getHealthDataFromTypes returns multiple VO2 Max data points',
        () async {
      ctx.channel.when('getData', [
        HealthFixtures.numericPoint(uuid: 'vo2-1', value: 40.0),
        HealthFixtures.numericPoint(uuid: 'vo2-2', value: 45.5),
        HealthFixtures.numericPoint(uuid: 'vo2-3', value: 38.2),
      ]);

      final result = await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.VO2_MAX],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(result, hasLength(3));
      expect(result.map((p) => p.type).toSet(), {HealthDataType.VO2_MAX});
    });
  });

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  group('VO2 Max – write', () {
    test('writeHealthData succeeds for VO2 Max', () async {
      ctx.channel.when('writeData', true);

      final success = await ctx.health.writeHealthData(
        value: 42.5,
        type: HealthDataType.VO2_MAX,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        recordingMethod: RecordingMethod.manual,
      );

      expect(success, isTrue);
    });

    test('writeHealthData sends correct keys for VO2 Max', () async {
      ctx.channel.when('writeData', true);

      await ctx.health.writeHealthData(
        value: 42.5,
        type: HealthDataType.VO2_MAX,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        recordingMethod: RecordingMethod.manual,
      );

      final call = ctx.channel.lastCallFor('writeData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataTypeKey'], HealthDataType.VO2_MAX.name);
      expect(
        args['dataUnitKey'],
        HealthDataUnit.MILLILITER_PER_KILOGRAM_PER_MINUTE.name,
      );
      expect(args['value'], 42.5);
      expect(args['recordingMethod'], RecordingMethod.manual.toInt());
    });

    test('writeHealthData forwards start and end time for VO2 Max', () async {
      ctx.channel.when('writeData', true);

      await ctx.health.writeHealthData(
        value: 50.0,
        type: HealthDataType.VO2_MAX,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      final call = ctx.channel.lastCallFor('writeData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['startTime'], HealthFixtures.start.millisecondsSinceEpoch);
      expect(args['endTime'], HealthFixtures.end.millisecondsSinceEpoch);
    });

    test('writeHealthData returns false when platform returns false', () async {
      ctx.channel.when('writeData', false);

      final success = await ctx.health.writeHealthData(
        value: 42.5,
        type: HealthDataType.VO2_MAX,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(success, isFalse);
    });

    test('writeHealthData rejects invalid time range for VO2 Max', () {
      expect(
        () => ctx.health.writeHealthData(
          value: 42.5,
          type: HealthDataType.VO2_MAX,
          startTime: HealthFixtures.end,
          endTime: HealthFixtures.start,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  group('VO2 Max – parsing', () {
    test('VO2 Max data point parses numeric value correctly', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.VO2_MAX,
        HealthFixtures.numericPoint(uuid: 'vo2-1', value: 42.5),
        null,
      );

      expect(point.type, HealthDataType.VO2_MAX);
      expect(point.unit, HealthDataUnit.MILLILITER_PER_KILOGRAM_PER_MINUTE);
      expect(point.value, isA<NumericHealthValue>());
      expect((point.value as NumericHealthValue).numericValue, 42.5);
    });

    test('VO2 Max data point preserves uuid and source info', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.VO2_MAX,
        HealthFixtures.numericPoint(
          uuid: 'vo2-unique-id',
          value: 38.0,
          sourceId: 'my-source',
          sourceName: 'My App',
        ),
        null,
      );

      expect(point.uuid, 'vo2-unique-id');
      expect(point.sourceId, 'my-source');
      expect(point.sourceName, 'My App');
    });

    test('VO2 Max data point serializes to JSON and back', () {
      final original = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.VO2_MAX,
        HealthFixtures.numericPoint(uuid: 'vo2-1', value: 44.0),
        null,
      );

      final json = original.toJson();
      expect(json['type'], HealthDataType.VO2_MAX.name);
      expect(json['unit'], HealthDataUnit.MILLILITER_PER_KILOGRAM_PER_MINUTE.name);

      final restored = HealthDataPoint.fromJson(json);
      expect(restored.type, HealthDataType.VO2_MAX);
      expect(restored.unit, HealthDataUnit.MILLILITER_PER_KILOGRAM_PER_MINUTE);
      expect(
        (restored.value as NumericHealthValue).numericValue,
        (original.value as NumericHealthValue).numericValue,
      );
    });

    test('dataTypeToUnit maps VO2_MAX to MILLILITER_PER_KILOGRAM_PER_MINUTE',
        () {
      expect(
        dataTypeToUnit[HealthDataType.VO2_MAX],
        HealthDataUnit.MILLILITER_PER_KILOGRAM_PER_MINUTE,
      );
    });
  });
}
