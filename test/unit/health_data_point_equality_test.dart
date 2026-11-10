import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';

/// A point as a read returns it: every read builds new metadata maps and lists.
HealthDataPoint _readPoint({required HealthValue value, Map<String, dynamic>? metadata}) => HealthDataPoint(
  uuid: 'id-1',
  value: value,
  type: HealthDataType.STEPS,
  unit: HealthDataUnit.COUNT,
  dateFrom: HealthFixtures.start,
  dateTo: HealthFixtures.end,
  sourcePlatform: HealthPlatformType.appleHealth,
  sourceDeviceId: 'device-id',
  sourceId: 'source-id',
  sourceName: 'source-name',
  metadata: metadata,
);

/// iOS metadata as the native side sends it, with nested maps and lists.
Map<String, dynamic> _metadata() => {
  'HKWasUserEntered': false,
  'HKMetadataKeyHeartRateEventThreshold': 120,
  'nested': {
    'list': [1, 2.5, 'three'],
    'map': {'a': true},
  },
};

ElectrocardiogramHealthValue _ecg() => ElectrocardiogramHealthValue(
  voltageValues: [
    ElectrocardiogramVoltageValue(voltage: 0.1, timeSinceSampleStart: 0),
    ElectrocardiogramVoltageValue(voltage: 0.2, timeSinceSampleStart: 0.002),
  ],
  averageHeartRate: 70,
  samplingFrequency: 512,
  classification: ElectrocardiogramClassification.SINUS_RHYTHM,
);

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

  group('HealthDataPoint equality', () {
    test('compares metadata by its contents, also nested maps and lists', () {
      final first = _readPoint(value: NumericHealthValue(numericValue: 42), metadata: _metadata());
      final second = _readPoint(value: NumericHealthValue(numericValue: 42), metadata: _metadata());

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(ctx.health.removeDuplicates([first, second]), [first]);
    });

    test('tells points with different metadata apart', () {
      final changed = _metadata()
        ..['nested'] = {
          'list': [1, 2.5, 'four'],
        };
      final first = _readPoint(value: NumericHealthValue(numericValue: 42), metadata: _metadata());
      final second = _readPoint(value: NumericHealthValue(numericValue: 42), metadata: changed);

      expect(first, isNot(second));
      expect(ctx.health.removeDuplicates([first, second]), hasLength(2));
    });

    test('compares ECG voltages by their contents', () {
      expect(_ecg(), _ecg());
      expect(_ecg().hashCode, _ecg().hashCode);
      final first = _readPoint(value: _ecg(), metadata: _metadata());
      final second = _readPoint(value: _ecg(), metadata: _metadata());
      expect(ctx.health.removeDuplicates([first, second]), [first]);
    });
  });
}
