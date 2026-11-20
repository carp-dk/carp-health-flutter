import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_on_android.dart';
import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;
  late List<String> printed;

  setUp(() async {
    ctx = HealthTestContext();
    await ctx.setUp();
    ctx.channel.when('getIntervalData', <Object?>[]);
    printed = [];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message ?? '');
    addTearDown(() => debugPrint = original);
  });

  tearDown(() async {
    await ctx.tearDown();
  });

  Future<void> readIntervals(Health health, List<HealthDataType> types, List<RecordingMethod> filter) =>
      health.getHealthIntervalDataFromTypes(
        startDate: HealthFixtures.start,
        endDate: HealthFixtures.end,
        types: types,
        interval: 3600,
        recordingMethodsToFilter: filter,
      );

  List<String> warnings() => printed.where((line) => line.contains('cannot leave out')).toList();

  group('Interval reads warn about a recording method filter they cannot apply', () {
    test('on Android, for the types other than sleep', () async {
      await readIntervals(
        HealthOnAndroid(),
        [HealthDataType.STEPS, HealthDataType.SLEEP_DEEP, HealthDataType.HEART_RATE],
        [RecordingMethod.manual],
      );

      expect(warnings(), hasLength(1));
      expect(warnings().single, contains('STEPS, HEART_RATE on Android'));
      expect(warnings().single, isNot(contains('SLEEP_DEEP')));
      // The data is still read, unfiltered.
      expect(ctx.channel.callsFor('getIntervalData'), hasLength(3));
    });

    test('not on Android for sleep types, nor without a filter', () async {
      await readIntervals(
        HealthOnAndroid(),
        [HealthDataType.SLEEP_SESSION, HealthDataType.SLEEP_DEEP],
        [RecordingMethod.manual],
      );
      await readIntervals(HealthOnAndroid(), [HealthDataType.STEPS], []);

      expect(warnings(), isEmpty);
    });

    test('on iOS, for the recording methods other than manual', () async {
      await readIntervals(HealthOnIOS(), [HealthDataType.STEPS], [RecordingMethod.manual]);
      expect(warnings(), isEmpty);

      await readIntervals(HealthOnIOS(), [HealthDataType.STEPS], [RecordingMethod.manual, RecordingMethod.automatic]);
      expect(warnings(), hasLength(1));
      expect(warnings().single, contains('cannot leave out automatic on iOS'));
    });
  });
}
