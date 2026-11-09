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
      expect(() => ctx.health.deleteByUUID(uuid: ''), throwsA(isA<ArgumentError>()));
    });

    test('deleteByUUID forwards payload', () async {
      ctx.channel.when('deleteByUUID', true);

      final success = await ctx.health.deleteByUUID(uuid: 'uuid-1', type: HealthDataType.HEART_RATE);

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
}
