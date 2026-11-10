import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

/// An audiogram as the iOS side sends it, with 1000 Hz tested on the right ear
/// only and 4000 Hz on the left ear only.
Map<String, dynamic> _audiogram() => {
  'uuid': 'audiogram-1',
  'frequencies': [500, 1000, 4000],
  'leftEarSensitivities': [20, null, 35.5],
  'rightEarSensitivities': [15, 25, null],
  'date_from': HealthFixtures.start.millisecondsSinceEpoch,
  'date_to': HealthFixtures.end.millisecondsSinceEpoch,
  'source_id': 'source-id',
  'source_name': 'source-name',
};

final _expected = AudiogramHealthValue(
  frequencies: [500, 1000, 4000],
  leftEarSensitivities: [20, null, 35.5],
  rightEarSensitivities: [15, 25, null],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audiogram parsing', () {
    test('a frequency tested on one ear only has null for the other ear', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.AUDIOGRAM,
        _audiogram(),
        HealthDataUnit.DECIBEL_HEARING_LEVEL.name,
      );

      expect(point.value, _expected);
      expect(point.unit, HealthDataUnit.DECIBEL_HEARING_LEVEL);
    });

    test('the null thresholds survive JSON', () {
      final point = HealthDataPoint.fromHealthDataPoint(HealthDataType.AUDIOGRAM, _audiogram(), null);

      final json = jsonDecode(jsonEncode(point.toJson())) as Map<String, dynamic>;

      expect(HealthDataPoint.fromJson(json).value, _expected);
    });

    test('equal values have equal hash codes', () {
      // Doubles, as HealthKit sends them, are equal to the ints of _expected.
      final fromDoubles = AudiogramHealthValue(
        frequencies: [500.0, 1000.0, 4000.0],
        leftEarSensitivities: [20.0, null, 35.5],
        rightEarSensitivities: [15.0, 25.0, null],
      );

      expect(fromDoubles, _expected);
      expect(fromDoubles.hashCode, _expected.hashCode);
    });
  });

  group('Audiogram on the method channel', () {
    late HealthTestContext ctx;

    setUp(() async {
      ctx = HealthTestContext();
      await ctx.setUp();
    });

    tearDown(() async {
      await ctx.tearDown();
    });

    test('a read keeps the null thresholds', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page([_audiogram()]));

      final points = await ctx.collect([HealthDataType.AUDIOGRAM]);

      expect(points.single.value, _expected);
    });

    test('removeDuplicates removes an audiogram read twice', () async {
      ctx.channel.when('getDataPage', HealthFixtures.page([_audiogram()]));

      final first = await ctx.collect([HealthDataType.AUDIOGRAM]);
      final second = await ctx.collect([HealthDataType.AUDIOGRAM]);

      expect(ctx.health.removeDuplicates([...first, ...second]), hasLength(1));
    });

    test('writeAudiogram throws the error for an audiogram HealthKit does not accept', () async {
      ctx.channel.whenSequence('writeAudiogram', [
        PlatformException(code: 'INVALID_ARGUMENT', message: 'An audiogram can have at most 30 frequencies'),
      ]);

      await expectLater(
        ctx.health.writeAudiogram(
          frequencies: [for (var i = 1; i <= 31; i++) i * 100.0],
          leftEarSensitivities: List.filled(31, 20.0),
          rightEarSensitivities: List.filled(31, 20.0),
          startTime: HealthFixtures.start,
        ),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGUMENT')),
      );
    });
  });
}
