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

  group('Read APIs', () {
    test('getHealthDataFromTypes forwards preferred units and filters', () async {
      ctx.channel.when('getData', [HealthFixtures.numericPoint()]);

      final result = await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        preferredUnits: {HealthDataType.HEART_RATE: HealthDataUnit.COUNT},
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        recordingMethodsToFilter: [RecordingMethod.manual],
      );

      expect(result, hasLength(1));
      expect(result.first.value, isA<NumericHealthValue>());

      final call = ctx.channel.lastCallFor('getData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataTypeKey'], HealthDataType.HEART_RATE.name);
      expect(args['dataUnitKey'], HealthDataUnit.COUNT.name);
      expect(args['recordingMethodsToFilter'], [RecordingMethod.manual.toInt()]);
    });

    test('getHealthDataByUUID throws when UUID is empty', () {
      expect(
        () => ctx.health.getHealthDataByUUID(uuid: '', type: HealthDataType.HEART_RATE),
        throwsA(isA<HealthException>()),
      );
    });

    test('getHealthDataByUUID forwards UUID and type', () async {
      ctx.channel.when('getDataByUUID', HealthFixtures.numericPoint());

      final result = await ctx.health.getHealthDataByUUID(
        uuid: 'uuid-1',
        type: HealthDataType.HEART_RATE,
      );

      expect(result, isNotNull);
      final call = ctx.channel.lastCallFor('getDataByUUID');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['uuid'], 'uuid-1');
      expect(args['dataTypeKey'], HealthDataType.HEART_RATE.name);
    });

    test('getHealthIntervalDataFromTypes forwards interval query', () async {
      ctx.channel.when('getIntervalData', [HealthFixtures.numericPoint()]);

      final result = await ctx.health.getHealthIntervalDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startDate: HealthFixtures.start,
        endDate: HealthFixtures.end,
        interval: 30,
        recordingMethodsToFilter: [RecordingMethod.automatic],
      );

      expect(result, hasLength(1));
      expect(result.first.type, HealthDataType.HEART_RATE);

      final call = ctx.channel.lastCallFor('getIntervalData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['interval'], 30);
      expect(args['recordingMethodsToFilter'], [RecordingMethod.automatic.toInt()]);
    });

    test('getHealthAggregateDataFromTypes forwards aggregate query', () async {
      ctx.channel.when('getAggregateData', [HealthFixtures.workoutPoint()]);

      final result = await ctx.health.getHealthAggregateDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startDate: HealthFixtures.start,
        endDate: HealthFixtures.end,
        activitySegmentDuration: 60,
      );

      expect(result, hasLength(1));
      expect(result.first.type, HealthDataType.WORKOUT);
      expect(result.first.value, isA<WorkoutHealthValue>());

      final call = ctx.channel.lastCallFor('getAggregateData');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataTypeKeys'], [HealthDataType.WORKOUT.name]);
      expect(args['activitySegmentDuration'], 60);
    });

    test('getTotalStepsInInterval includes manual filter when disabled', () async {
      ctx.channel.when('getTotalStepsInInterval', 1234);

      final total = await ctx.health.getTotalStepsInInterval(
        HealthFixtures.start,
        HealthFixtures.end,
        includeManualEntry: false,
      );

      expect(total, 1234);
      final call = ctx.channel.lastCallFor('getTotalStepsInInterval');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['recordingMethodsToFilter'], [RecordingMethod.manual.toInt()]);
    });

    test('removeDuplicates removes identical points', () {
      final point = HealthDataPoint(
        uuid: 'id-1',
        value: NumericHealthValue(numericValue: 42),
        type: HealthDataType.STEPS,
        unit: HealthDataUnit.COUNT,
        dateFrom: HealthFixtures.start,
        dateTo: HealthFixtures.end,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'device-id',
        sourceId: 'source-id',
        sourceName: 'source-name',
      );

      final result = ctx.health.removeDuplicates([point, point]);

      expect(result, hasLength(1));
    });
  });
}
