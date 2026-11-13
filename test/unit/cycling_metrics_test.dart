import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/error_matchers.dart';
import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

/// The cycling metrics, read only on both platforms, and their units.
const _units = {
  HealthDataType.POWER: HealthDataUnit.WATT,
  HealthDataType.CYCLING_CADENCE: HealthDataUnit.REVOLUTION_PER_MINUTE,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cycling metrics', () {
    test('have their own default units', () {
      for (final MapEntry(key: type, value: unit) in _units.entries) {
        expect(dataTypeToUnit[type], unit);
      }
    });

    test('are available on iOS and Android', () {
      for (final type in _units.keys) {
        expect(dataTypeKeysIOS, contains(type));
        expect(dataTypeKeysAndroid, contains(type));
      }
    });

    test('have the names the native sides use as keys', () {
      // HealthKit and Health Connect look the type and the unit up by name.
      expect(_units.keys.map((type) => type.name), ['POWER', 'CYCLING_CADENCE']);
      expect(_units.values.map((unit) => unit.name), ['WATT', 'REVOLUTION_PER_MINUTE']);
    });

    test('round-trip through JSON', () {
      // Fails if lib/health.g.dart was not regenerated for the new enum values.
      for (final MapEntry(key: type, value: unit) in _units.entries) {
        final point = HealthDataPoint.fromHealthDataPoint(type, HealthFixtures.numericPoint(value: 215), unit.name);
        final json = point.toJson();
        expect(json['type'], type.name);
        expect(json['unit'], unit.name);

        final restored = HealthDataPoint.fromJson(json);
        expect(restored.type, type);
        expect(restored.unit, unit);
        expect((restored.value as NumericHealthValue).numericValue, 215);
      }
    });
  });

  group('Cycling metrics on the method channel', () {
    late HealthTestContext ctx;

    setUp(() async {
      ctx = HealthTestContext();
      await ctx.setUp();
    });

    tearDown(() async {
      await ctx.tearDown();
    });

    test('are read in their units as numeric values', () async {
      await ctx.serve({
        HealthDataType.POWER: [
          HealthFixtures.page([HealthFixtures.numericPoint(uuid: 'power', value: 215)]),
        ],
        HealthDataType.CYCLING_CADENCE: [
          HealthFixtures.page([HealthFixtures.numericPoint(uuid: 'cadence', value: 90)]),
        ],
      });

      final points = await ctx.collect(_units.keys.toList());

      expect(ctx.pageCalls().map((args) => (args['dataTypeKey'], args['dataUnitKey'])), [
        ('POWER', 'WATT'),
        ('CYCLING_CADENCE', 'REVOLUTION_PER_MINUTE'),
      ]);
      expect(points.map((point) => (point.type, point.unit, point.value)), [
        (HealthDataType.POWER, HealthDataUnit.WATT, NumericHealthValue(numericValue: 215)),
        (HealthDataType.CYCLING_CADENCE, HealthDataUnit.REVOLUTION_PER_MINUTE, NumericHealthValue(numericValue: 90)),
      ]);
    });

    test('a read before iOS 17, where HealthKit has no such types, fails with notSupported', () async {
      ctx.channel.whenSequence('getDataPage', [PlatformException(code: 'NOT_SUPPORTED')]);

      await expectLater(
        ctx.collect([HealthDataType.POWER]),
        throwsA(platformError('NOT_SUPPORTED', type: HealthDataType.POWER)),
      );
    });

    test('are not written: the writes throw without calling the native side', () async {
      for (final type in _units.keys) {
        await expectLater(
          ctx.health.writeHealthData(
            value: 1,
            type: type,
            startTime: HealthFixtures.start,
            endTime: HealthFixtures.end,
          ),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          ctx.health.writeHealthDataUUID(
            value: 1,
            type: type,
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
