import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_android.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

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

  group('Sexual activity – type & enum', () {
    test('is available on iOS and Android with NO_UNIT', () {
      expect(dataTypeKeysIOS, contains(HealthDataType.SEXUAL_ACTIVITY));
      expect(dataTypeKeysAndroid, contains(HealthDataType.SEXUAL_ACTIVITY));
      expect(HealthDataType.SEXUAL_ACTIVITY.name, 'SEXUAL_ACTIVITY');
      expect(dataTypeToUnit[HealthDataType.SEXUAL_ACTIVITY], HealthDataUnit.NO_UNIT);
    });

    test('maps protection values to and from Health Connect constants', () {
      expect(SexualActivityProtection.fromHealthConnect(0), SexualActivityProtection.unknown);
      expect(SexualActivityProtection.fromHealthConnect(1), SexualActivityProtection.protected);
      expect(SexualActivityProtection.fromHealthConnect(2), SexualActivityProtection.unprotected);
      expect(SexualActivityProtection.fromHealthConnect(null), SexualActivityProtection.unknown);
      expect(SexualActivityProtection.fromHealthConnect(99), SexualActivityProtection.unknown);

      expect(SexualActivityProtection.unknown.toHealthConnect(), 0);
      expect(SexualActivityProtection.protected.toHealthConnect(), 1);
      expect(SexualActivityProtection.unprotected.toHealthConnect(), 2);
    });

    test('maps protection values to and from HealthKit metadata booleans', () {
      expect(SexualActivityProtection.fromHealthKit(null), SexualActivityProtection.unknown);
      expect(SexualActivityProtection.fromHealthKit(true), SexualActivityProtection.protected);
      expect(SexualActivityProtection.fromHealthKit(false), SexualActivityProtection.unprotected);

      expect(SexualActivityProtection.unknown.toHealthKit(), isNull);
      expect(SexualActivityProtection.protected.toHealthKit(), isTrue);
      expect(SexualActivityProtection.unprotected.toHealthKit(), isFalse);
    });
  });

  group('Sexual activity – parsing & JSON', () {
    Map<String, dynamic> rawPoint({int value = 0, Map<String, dynamic>? metadata, String uuid = 'sa-1'}) => {
      'uuid': uuid,
      'value': value,
      'date_from': HealthFixtures.start.millisecondsSinceEpoch,
      'date_to': HealthFixtures.start.millisecondsSinceEpoch,
      'source_id': 'source-1',
      'source_name': 'Example App',
      'recording_method': RecordingMethod.manual.toInt(),
      if (metadata != null) 'metadata': metadata,
    };

    test('parses Android Health Connect integer protection values', () {
      final unknown = HealthDataPoint.fromHealthDataPoint(HealthDataType.SEXUAL_ACTIVITY, rawPoint(value: 0), null);
      final protected = HealthDataPoint.fromHealthDataPoint(HealthDataType.SEXUAL_ACTIVITY, rawPoint(value: 1), null);
      final unprotected = HealthDataPoint.fromHealthDataPoint(HealthDataType.SEXUAL_ACTIVITY, rawPoint(value: 2), null);

      expect(unknown.unit, HealthDataUnit.NO_UNIT);
      expect(unknown.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.unknown));
      expect(protected.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.protected));
      expect(unprotected.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.unprotected));
    });

    test('parses iOS HealthKit protection metadata (bool, num, and omitted)', () {
      final protectedBool = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.SEXUAL_ACTIVITY,
        rawPoint(value: 0, metadata: {'HKSexualActivityProtectionUsed': true}),
        null,
      );
      final unprotectedBool = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.SEXUAL_ACTIVITY,
        rawPoint(value: 0, metadata: {'HKSexualActivityProtectionUsed': false}),
        null,
      );
      final protectedNum = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.SEXUAL_ACTIVITY,
        rawPoint(value: 0, metadata: {'HKSexualActivityProtectionUsed': 1.0}),
        null,
      );
      final unprotectedNum = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.SEXUAL_ACTIVITY,
        rawPoint(value: 0, metadata: {'HKSexualActivityProtectionUsed': 0}),
        null,
      );
      final omitted = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.SEXUAL_ACTIVITY,
        rawPoint(value: 0, metadata: {'HKWasUserEntered': true}),
        null,
      );

      expect(protectedBool.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.protected));
      expect(unprotectedBool.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.unprotected));
      expect(protectedNum.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.protected));
      expect(unprotectedNum.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.unprotected));
      expect(omitted.value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.unknown));
    });

    test('serializes to JSON and back with equality and hashCode', () {
      for (final protection in SexualActivityProtection.values) {
        final value = SexualActivityHealthValue(protectionUsed: protection);
        final original = HealthDataPoint.fromHealthDataPoint(
          HealthDataType.SEXUAL_ACTIVITY,
          rawPoint(value: protection.toHealthConnect()),
          null,
        );

        final json = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
        expect(json['type'], 'SEXUAL_ACTIVITY');
        expect(json['unit'], 'NO_UNIT');

        final restored = HealthDataPoint.fromJson(json);
        expect(restored.value, value);
        expect(restored.value.hashCode, value.hashCode);
        expect(restored, original);
      }

      expect(
        SexualActivityHealthValue(protectionUsed: SexualActivityProtection.protected),
        isNot(SexualActivityHealthValue(protectionUsed: SexualActivityProtection.unprotected)),
      );
      expect(
        SexualActivityHealthValue(protectionUsed: SexualActivityProtection.protected).toString(),
        'SexualActivityHealthValue - protectionUsed: protected',
      );
    });
  });

  group('Sexual activity – read', () {
    test('getHealthDataFromTypes returns parsed SexualActivityHealthValue points', () async {
      await ctx.serve({
        HealthDataType.SEXUAL_ACTIVITY: [
          HealthFixtures.page([
            {
              'uuid': 'sa-1',
              'value': 1,
              'date_from': HealthFixtures.start.millisecondsSinceEpoch,
              'date_to': HealthFixtures.start.millisecondsSinceEpoch,
              'source_id': 'src',
              'source_name': 'App',
              'recording_method': RecordingMethod.manual.toInt(),
            },
            {
              'uuid': 'sa-2',
              'value': 0,
              'date_from': HealthFixtures.end.millisecondsSinceEpoch,
              'date_to': HealthFixtures.end.millisecondsSinceEpoch,
              'source_id': 'src',
              'source_name': 'App',
              'recording_method': RecordingMethod.manual.toInt(),
              'metadata': {'HKSexualActivityProtectionUsed': false},
            },
          ]),
        ],
      });

      final points = await ctx.collect([HealthDataType.SEXUAL_ACTIVITY]);

      expect(points, hasLength(2));
      expect(points[0].type, HealthDataType.SEXUAL_ACTIVITY);
      expect(points[0].value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.protected));
      expect(points[1].value, SexualActivityHealthValue(protectionUsed: SexualActivityProtection.unprotected));
    });
  });

  group('Sexual activity – write', () {
    test('writeSexualActivity sends protectionUsed, timestamps, recordingMethod and clientRecordId', () async {
      ctx.channel.when('writeSexualActivity', true);

      final saved = await ctx.health.writeSexualActivity(
        protectionUsed: SexualActivityProtection.protected,
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
        recordingMethod: RecordingMethod.manual,
        clientRecordId: 'sa-client-1',
        clientRecordVersion: 2.0,
      );

      expect(saved, isTrue);
      final call = ctx.channel.lastCallFor('writeSexualActivity');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['dataTypeKey'], 'SEXUAL_ACTIVITY');
      expect(args['protectionUsed'], isTrue);
      expect(args['startTime'], HealthFixtures.start.millisecondsSinceEpoch);
      expect(args['endTime'], HealthFixtures.end.millisecondsSinceEpoch);
      expect(args['recordingMethod'], RecordingMethod.manual.toInt());
      expect(args['clientRecordId'], 'sa-client-1');
      expect(args['clientRecordVersion'], 2.0);
    });

    test('writeSexualActivity defaults protectionUsed to unknown (null) and endTime to startTime', () async {
      ctx.channel.when('writeSexualActivity', true);

      final saved = await ctx.health.writeSexualActivity(startTime: HealthFixtures.start);

      expect(saved, isTrue);
      final args = Map<String, dynamic>.from(ctx.channel.lastCallFor('writeSexualActivity')!.arguments as Map);
      expect(args['protectionUsed'], isNull);
      expect(args['startTime'], HealthFixtures.start.millisecondsSinceEpoch);
      expect(args['endTime'], HealthFixtures.start.millisecondsSinceEpoch);
    });

    test('writeSexualActivity sends false for unprotected', () async {
      ctx.channel.when('writeSexualActivity', false);

      final saved = await ctx.health.writeSexualActivity(
        protectionUsed: SexualActivityProtection.unprotected,
        startTime: HealthFixtures.start,
      );

      expect(saved, isFalse);
      final args = Map<String, dynamic>.from(ctx.channel.lastCallFor('writeSexualActivity')!.arguments as Map);
      expect(args['protectionUsed'], isFalse);
    });

    test('writeSexualActivity rejects startTime after endTime', () {
      expect(
        () => ctx.health.writeSexualActivity(
          protectionUsed: SexualActivityProtection.protected,
          startTime: HealthFixtures.end,
          endTime: HealthFixtures.start,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(ctx.channel.calls, isEmpty);
    });

    test('writeHealthData and writeHealthDataUUID reject SEXUAL_ACTIVITY on both platforms', () async {
      for (final health in [HealthOnAndroid(), HealthOnIOS()]) {
        await expectLater(
          health.writeHealthData(
            value: 1,
            type: HealthDataType.SEXUAL_ACTIVITY,
            startTime: HealthFixtures.start,
            endTime: HealthFixtures.end,
          ),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          health.writeHealthDataUUID(
            value: 1,
            type: HealthDataType.SEXUAL_ACTIVITY,
            startTime: HealthFixtures.start,
            endTime: HealthFixtures.end,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(ctx.channel.calls, isEmpty);
    });
  });
}
