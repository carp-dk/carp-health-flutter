import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_rules.dart';

const _ios = HealthPlatformType.appleHealth;
const _android = HealthPlatformType.googleHealthConnect;

void main() {
  group('the rules only name types of their platform', () {
    test('iOS rules', () {
      expect(dataTypeKeysIOS, containsAll(TypeRules.iosMinimumVersion.keys));
      expect(dataTypeKeysIOS, containsAll(TypeRules.iosReadOnly));
      expect(dataTypeKeysIOS, containsAll(TypeRules.characteristics));
      expect(dataTypeKeysIOS, containsAll(TypeRules.iosTypesWithoutIntervals));
    });

    test('Android rules', () {
      expect(dataTypeKeysAndroid, containsAll(TypeRules.androidFeatureTypes));
      expect(dataTypeKeysAndroid, containsAll(TypeRules.androidIntervalTypes));
    });

    test('iOS read-only types are not Android types, so READ access for them is safe anywhere', () {
      expect(TypeRules.iosReadOnly.intersection(dataTypeKeysAndroid.toSet()), isEmpty);
      expect(TypeRules.characteristics.intersection(dataTypeKeysAndroid.toSet()), isEmpty);
    });

    test('dedicated write methods belong to types some platform has', () {
      final all = {...dataTypeKeysIOS, ...dataTypeKeysAndroid};
      expect(all, containsAll(TypeRules.dedicatedWriteMethods.keys));
    });
  });

  test('iOS versions are 16, 17 or 18', () {
    expect(TypeRules.iosMinimumVersion.values.toSet(), {16, 17, 18});
    expect(TypeRules.iosMinimumVersion[HealthDataType.ROWING_SPEED], 18);
    expect(TypeRules.iosMinimumVersion[HealthDataType.POWER], 17);
    expect(TypeRules.iosMinimumVersion[HealthDataType.UV_INDEX], 16);
  });

  group('read-only', () {
    test('POWER and CYCLING_CADENCE are never written', () {
      for (final platform in HealthPlatformType.values) {
        expect(TypeRules.isReadOnly(HealthDataType.POWER, platform), isTrue);
        expect(TypeRules.isReadOnly(HealthDataType.CYCLING_CADENCE, platform), isTrue);
      }
    });

    test('per platform', () {
      expect(TypeRules.isReadOnly(HealthDataType.ELECTROCARDIOGRAM, _ios), isTrue);
      expect(TypeRules.isReadOnly(HealthDataType.GENDER, _ios), isTrue);
      expect(TypeRules.isReadOnly(HealthDataType.SLEEP_UNKNOWN, _ios), isTrue);
      expect(TypeRules.isReadOnly(HealthDataType.SLEEP_UNKNOWN, _android), isFalse);
      expect(TypeRules.isReadOnly(HealthDataType.BODY_MASS_INDEX, _android), isTrue);
      expect(TypeRules.isReadOnly(HealthDataType.BODY_MASS_INDEX, _ios), isFalse);
      expect(TypeRules.isReadOnly(HealthDataType.STEPS, _ios), isFalse);
    });
  });

  test('writeHealthData leaves out types with a write method of their own', () {
    for (final platform in HealthPlatformType.values) {
      for (final type in TypeRules.dedicatedWriteMethods.keys) {
        expect(TypeRules.writesWithWriteHealthData(type, platform), isFalse, reason: type.name);
      }
      expect(TypeRules.writesWithWriteHealthData(HealthDataType.STEPS, platform), isTrue);
      expect(TypeRules.writesWithWriteHealthData(HealthDataType.SLEEP_ASLEEP, platform), isTrue);
    }
  });

  test('deletes skip what the app cannot write, and Android workout routes', () {
    expect(TypeRules.isDeletable(HealthDataType.WORKOUT_ROUTE, _android), isFalse);
    expect(TypeRules.isDeletable(HealthDataType.WORKOUT_ROUTE, _ios), isTrue);
    expect(TypeRules.isDeletable(HealthDataType.WORKOUT, _android), isTrue);
    expect(TypeRules.isDeletable(HealthDataType.APPLE_STAND_TIME, _ios), isFalse);
  });

  group('intervals', () {
    test('Android: the documented sleep types, sums, averages and minutes', () {
      expect(TypeRules.androidIntervalTypes, {
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_AWAKE_IN_BED,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_OUT_OF_BED,
        HealthDataType.SLEEP_UNKNOWN,
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.WATER,
        HealthDataType.HEART_RATE,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.POWER,
        HealthDataType.CYCLING_CADENCE,
        HealthDataType.SKIN_TEMPERATURE,
        HealthDataType.ACTIVITY_INTENSITY,
        HealthDataType.MINDFULNESS,
      });
      expect(TypeRules.hasIntervals(HealthDataType.VO2_MAX, _android), isFalse);
    });

    test('iOS: quantity types, sleep types and mindfulness', () {
      for (final type in [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.VO2_MAX,
        HealthDataType.WATER,
        HealthDataType.DIETARY_PROTEIN_CONSUMED,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_UNKNOWN,
        HealthDataType.MINDFULNESS,
        HealthDataType.ROWING_SPEED,
      ]) {
        expect(TypeRules.hasIntervals(type, _ios), isTrue, reason: type.name);
      }
      for (final type in [
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.WALKING_SPEED,
        HealthDataType.WORKOUT,
        HealthDataType.HEADACHE_MILD,
        HealthDataType.GENDER,
        HealthDataType.TOTAL_CALORIES_BURNED,
      ]) {
        expect(TypeRules.hasIntervals(type, _ios), isFalse, reason: type.name);
      }
    });
  });
}
