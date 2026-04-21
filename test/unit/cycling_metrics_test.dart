// Unit tests for the iOS 17+ / Health Connect cycling metrics added
// alongside this PR: `HealthDataType.POWER` and
// `HealthDataType.CYCLING_CADENCE`. These tests are pure-Dart and
// don't exercise the method channel — platform-specific behaviour is
// covered by manual integration testing on device (see README).

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthDataType.POWER', () {
    test('is present in the enum', () {
      expect(HealthDataType.values.contains(HealthDataType.POWER), isTrue);
    });

    test('maps to the WATT unit', () {
      expect(dataTypeToUnit[HealthDataType.POWER], HealthDataUnit.WATT);
    });

    test('is supported on iOS (iOS 17+ at runtime)', () {
      expect(dataTypeKeysIOS.contains(HealthDataType.POWER), isTrue);
    });

    test('is supported on Android (Health Connect PowerRecord)', () {
      expect(dataTypeKeysAndroid.contains(HealthDataType.POWER), isTrue);
    });

    test('round-trips through the generated JSON enum map', () {
      // Uses the regenerated _$HealthDataTypeEnumMap — catches forgotten
      // `build_runner` runs when someone adds an enum entry.
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.POWER,
        HealthFixtures.numericPoint(value: 215),
        HealthDataUnit.WATT.name,
      );
      final json = point.toJson();
      expect(json['type'], 'POWER');
      expect(json['unit'], 'WATT');

      final restored = HealthDataPoint.fromJson(json);
      expect(restored.type, HealthDataType.POWER);
      expect(restored.unit, HealthDataUnit.WATT);
      expect((restored.value as NumericHealthValue).numericValue, 215);
    });
  });

  group('HealthDataType.CYCLING_CADENCE', () {
    test('is present in the enum', () {
      expect(
        HealthDataType.values.contains(HealthDataType.CYCLING_CADENCE),
        isTrue,
      );
    });

    test('maps to REVOLUTION_PER_MINUTE', () {
      expect(
        dataTypeToUnit[HealthDataType.CYCLING_CADENCE],
        HealthDataUnit.REVOLUTION_PER_MINUTE,
      );
    });

    test('is listed for both platforms', () {
      expect(
        dataTypeKeysIOS.contains(HealthDataType.CYCLING_CADENCE),
        isTrue,
        reason: 'CYCLING_CADENCE must appear in dataTypeKeysIOS so '
            'hasPermissions / requestAuthorization can include it in '
            'the iOS 17+ bundle.',
      );
      expect(
        dataTypeKeysAndroid.contains(HealthDataType.CYCLING_CADENCE),
        isTrue,
        reason: 'CYCLING_CADENCE must appear in dataTypeKeysAndroid so '
            'Health Connect permissions resolve correctly.',
      );
    });

    test('round-trips through the generated JSON enum map', () {
      final point = HealthDataPoint.fromHealthDataPoint(
        HealthDataType.CYCLING_CADENCE,
        HealthFixtures.numericPoint(value: 90),
        HealthDataUnit.REVOLUTION_PER_MINUTE.name,
      );
      final json = point.toJson();
      expect(json['type'], 'CYCLING_CADENCE');
      expect(json['unit'], 'REVOLUTION_PER_MINUTE');

      final restored = HealthDataPoint.fromJson(json);
      expect(restored.type, HealthDataType.CYCLING_CADENCE);
      expect(restored.unit, HealthDataUnit.REVOLUTION_PER_MINUTE);
      expect((restored.value as NumericHealthValue).numericValue, 90);
    });
  });

  group('New HealthDataUnit entries', () {
    test('WATT and REVOLUTION_PER_MINUTE are in the enum', () {
      expect(HealthDataUnit.values.contains(HealthDataUnit.WATT), isTrue);
      expect(
        HealthDataUnit.values.contains(HealthDataUnit.REVOLUTION_PER_MINUTE),
        isTrue,
      );
    });

    test('their string names match the platform-side constants', () {
      // The iOS SwiftHealthPlugin and the Android HealthConstants.kt
      // key `unitDict` by the enum's `.name`. If these strings ever
      // drift from the Swift/Kotlin side the type lookup silently
      // returns nil and the read returns empty — hence the test.
      expect(HealthDataUnit.WATT.name, 'WATT');
      expect(
        HealthDataUnit.REVOLUTION_PER_MINUTE.name,
        'REVOLUTION_PER_MINUTE',
      );
    });
  });
}
