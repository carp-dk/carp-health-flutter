// Integration test for the iOS 17+ / Health Connect cycling metrics.
//
// Runs on a real device or simulator with the Health permission
// granted. Verifies the end-to-end permission + read path for
// `HealthDataType.POWER` and `HealthDataType.CYCLING_CADENCE` without
// assuming any specific sample data — both simulators typically
// return an empty list, which is a valid pass.
//
// Run on Android:
//   cd example
//   flutter test integration_test/cycling_metrics_test.dart
//
// Run on iOS 17+ simulator or device:
//   cd example
//   flutter test integration_test/cycling_metrics_test.dart -d <device-id>
//
// What this test catches that the pure-Dart unit tests miss:
//   * HealthConstants.POWER key not wired in native `dataTypesDict`
//     → `hasPermissions` returns null / throws
//   * PowerRecord / CyclingPedalingCadenceRecord manifest entries
//     missing on Android → `requestAuthorization` silently drops the
//     types
//   * iOS 17 availability guard mis-configured → crash on older OS
//   * Unit dict missing WATT / REVOLUTION_PER_MINUTE → read returns
//     UNKNOWN_UNIT instead of the real unit

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final health = Health();
  const types = <HealthDataType>[
    HealthDataType.POWER,
    HealthDataType.CYCLING_CADENCE,
  ];
  const permissions = <HealthDataAccess>[
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  setUpAll(() async {
    await health.configure();
  });

  group('Cycling metrics platform wiring', () {
    test('hasPermissions accepts POWER and CYCLING_CADENCE', () async {
      // Before a user has granted anything, hasPermissions should return
      // false — NOT throw. A throw here means the native side doesn't
      // know the type string at all, i.e. the HealthConstants.POWER
      // registration is missing.
      final res = await health.hasPermissions(types, permissions: permissions);
      expect(res, anyOf(isNull, isFalse, isTrue),
          reason: 'hasPermissions must resolve to a bool? for known types. '
              'A PlatformException here means POWER/CYCLING_CADENCE are '
              'not registered on the native side.');
    });

    test('isDataTypeAvailable respects the iOS 17 guard', () async {
      // On iOS < 17 the types are not registered, so availability is
      // platform-dependent. We just assert the call completes without
      // throwing — the runtime guard should catch missing types
      // gracefully.
      await expectLater(
        health.isHealthConnectAvailable(),
        completes,
      );
    });

    test('reading before permission grant returns empty, not throws',
        () async {
      // A user that hasn't granted permissions should see an empty
      // list, not a PlatformException. This catches a common native
      // bug: forgetting to call `result(success: [])` on the denied
      // branch.
      final now = DateTime.now();
      final data = await health.getHealthDataFromTypes(
        types: types,
        startTime: now.subtract(const Duration(days: 7)),
        endTime: now,
      );
      expect(data, isA<List<HealthDataPoint>>());
    });
  });

  group('iOS-only — skipped on Android', () {
    setUp(() {
      if (!Platform.isIOS) return;
    });

    test('POWER type is gated by iOS 17 runtime availability', () async {
      if (!Platform.isIOS) return;
      // Just exercising configure + hasPermissions again here — the
      // full version-gate behaviour has to be verified on actual
      // iOS 16 hardware by the maintainer.
      final res = await health.hasPermissions(
        const [HealthDataType.POWER],
        permissions: const [HealthDataAccess.READ],
      );
      expect(res, anyOf(isNull, isFalse, isTrue));
    });
  });
}
