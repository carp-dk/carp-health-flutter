import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/stub_device_info.dart';

/// A [Health] with the data types of Android, for the sleep types only Health
/// Connect has: the test host has the iOS ones.
class _AndroidTypesHealth extends Health {
  _AndroidTypesHealth() : super(deviceInfo: StubDeviceInfoPlugin());

  @override
  bool isDataTypeAvailable(HealthDataType dataType) => dataTypeKeysAndroid.contains(dataType);
}

/// A reply of the native getIntervalData method as both platforms send it: an
/// hour-long interval from [HealthFixtures.start] on for each of [values].
List<Map<String, Object?>> _intervals(List<num> values) => [
  for (final (hour, value) in values.indexed)
    {
      'value': value,
      'date_from': HealthFixtures.start.add(Duration(hours: hour)).millisecondsSinceEpoch,
      'date_to': HealthFixtures.start.add(Duration(hours: hour + 1)).millisecondsSinceEpoch,
      'source_id': '',
      'source_name': 'com.example.sleep',
    },
];

/// The sleep types of the test host, which has the iOS data types.
const _sleepTypes = [
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_IN_BED,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
];

/// The type and the numeric value of each of [points].
List<(HealthDataType, num)> _values(List<HealthDataPoint> points) => [
  for (final point in points) (point.type, (point.value as NumericHealthValue).numericValue),
];

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

  Future<List<HealthDataPoint>> readHours(List<HealthDataType> types, {Health? health}) =>
      (health ?? ctx.health).getHealthIntervalDataFromTypes(
        types: types,
        startDate: HealthFixtures.start,
        endDate: HealthFixtures.start.add(const Duration(hours: 3)),
        interval: 3600,
      );

  group('Interval data', () {
    test('of sleep types is the minutes of each interval that sleep covers, not its length', () async {
      ctx.channel.when('getIntervalData', _intervals([15.0, 60.0, 30.0]));

      final points = await readHours(_sleepTypes);

      expect(_values(points), [
        for (final type in _sleepTypes) ...[(type, 15.0), (type, 60.0), (type, 30.0)],
      ]);
      expect(points.first.dateTo.difference(points.first.dateFrom), const Duration(hours: 1));
    });

    test('of Android sleep sessions and stages is on the same scale', () async {
      ctx.channel.when('getIntervalData', _intervals([10.0]));
      const types = [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_AWAKE_IN_BED,
        HealthDataType.SLEEP_OUT_OF_BED,
        HealthDataType.SLEEP_UNKNOWN,
      ];

      final points = await readHours(types, health: _AndroidTypesHealth());

      expect(_values(points), [for (final type in types) (type, 10.0)]);
    });

    test('of other types is the value the platform computed', () async {
      ctx.channel.when('getIntervalData', _intervals([72.5, 64]));

      expect(_values(await readHours([HealthDataType.HEART_RATE])), [
        (HealthDataType.HEART_RATE, 72.5),
        (HealthDataType.HEART_RATE, 64),
      ]);
    });

    test('of activity intensity is the intensity minutes Health Connect computed', () async {
      ctx.channel.when('getIntervalData', _intervals([12.5]));

      final points = await readHours([HealthDataType.ACTIVITY_INTENSITY], health: _AndroidTypesHealth());

      expect(_values(points), [(HealthDataType.ACTIVITY_INTENSITY, 12.5)]);
    });

    test('keeps its value through JSON', () async {
      ctx.channel.when('getIntervalData', _intervals([15.0]));

      final point = (await readHours([HealthDataType.SLEEP_DEEP])).single;

      expect(_values([HealthDataPoint.fromJson(point.toJson())]), [(HealthDataType.SLEEP_DEEP, 15.0)]);
    });

    for (final mode in HealthIsolateMode.values) {
      test('is parsed the same in $mode', () async {
        ctx.health.isolateMode = mode;
        ctx.channel.when('getIntervalData', _intervals([15.0, 60.0]));

        expect(_values(await readHours([HealthDataType.SLEEP_DEEP])), [
          (HealthDataType.SLEEP_DEEP, 15.0),
          (HealthDataType.SLEEP_DEEP, 60.0),
        ]);
      });
    }

    test('leaves reads of sleep types as they were: their value is the minutes a point spans', () async {
      // 4 is HealthKit's category value for deep sleep.
      final deepSleep = HealthFixtures.numericPoint(
        value: 4,
        to: HealthFixtures.start.add(const Duration(minutes: 25)),
      );
      ctx.channel.when('getDataPage', HealthFixtures.page([deepSleep]));

      final points = await ctx.health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_DEEP],
        startTime: HealthFixtures.start,
        endTime: HealthFixtures.end,
      );

      expect(_values(points), [(HealthDataType.SLEEP_DEEP, 25.0)]);
    });
  });
}
