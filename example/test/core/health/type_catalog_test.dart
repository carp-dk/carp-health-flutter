import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/core/health/type_rules.dart';

import '../support/fake_health.dart';

Future<TypeCatalog> _androidCatalog({Map<String, bool>? features}) async {
  final capabilities = PlatformCapabilities(
    FakeHealth(features: features ?? allFeatures()),
    platform: HealthPlatformType.googleHealthConnect,
  );
  await capabilities.refresh();
  return TypeCatalog(capabilities);
}

TypeCatalog _iosCatalog(int version) => TypeCatalog(
  PlatformCapabilities(FakeHealth(sdkStatus: null), platform: HealthPlatformType.appleHealth, iosMajorVersion: version),
);

void main() {
  group('Android', () {
    test('offers every Android type when Health Connect has every feature', () async {
      final catalog = await _androidCatalog();
      expect(catalog.available.toSet(), dataTypeKeysAndroid.toSet());
    });

    test('follows the capabilities: feature types appear after a refresh finds them', () async {
      final health = FakeHealth();
      final capabilities = PlatformCapabilities(health, platform: HealthPlatformType.googleHealthConnect);
      final catalog = TypeCatalog(capabilities);
      await capabilities.refresh();
      expect(catalog.available, isNot(contains(HealthDataType.MINDFULNESS)));

      health.features[FakeCheck.mindfulness] = true;
      await capabilities.refresh();
      expect(catalog.available, contains(HealthDataType.MINDFULNESS));
      expect(catalog.writableTypes, contains(HealthDataType.MINDFULNESS));
    });

    test('writable types exclude dedicated write methods, read-only types and BMI', () async {
      final catalog = await _androidCatalog();
      for (final type in [
        HealthDataType.WORKOUT,
        HealthDataType.NUTRITION,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.MENSTRUATION_FLOW,
        HealthDataType.SEXUAL_ACTIVITY,
        HealthDataType.ACTIVITY_INTENSITY,
        HealthDataType.WORKOUT_ROUTE,
        HealthDataType.POWER,
        HealthDataType.BODY_MASS_INDEX,
      ]) {
        expect(catalog.isWritable(type), isFalse, reason: type.name);
      }
      expect(catalog.writableTypes, containsAll([HealthDataType.STEPS, HealthDataType.SLEEP_SESSION]));
      expect(catalog.dedicatedWriteMethod(HealthDataType.NUTRITION), 'writeMeal');
    });

    test('deletable types skip BMI and workout routes', () async {
      final catalog = await _androidCatalog();
      expect(catalog.isDeletable(HealthDataType.BODY_MASS_INDEX), isFalse);
      expect(catalog.isDeletable(HealthDataType.WORKOUT_ROUTE), isFalse);
      expect(catalog.isDeletable(HealthDataType.WORKOUT), isTrue);
      expect(catalog.isDeletable(HealthDataType.NUTRITION), isTrue);
    });

    test('interval types are the Health Connect aggregates and sleep types', () async {
      final catalog = await _androidCatalog();
      expect(catalog.intervalTypes.toSet(), TypeRules.androidIntervalTypes);
      expect(catalog.hasIntervals(HealthDataType.VO2_MAX), isFalse);
    });
  });

  group('iOS', () {
    test('leaves out types newer than the iOS version', () {
      final ios16 = _iosCatalog(16);
      expect(ios16.available, contains(HealthDataType.RUNNING_POWER));
      expect(ios16.available, isNot(contains(HealthDataType.POWER)));
      expect(_iosCatalog(18).available.toSet(), dataTypeKeysIOS.toSet());
    });

    test('read-only types are neither writable nor deletable', () {
      final catalog = _iosCatalog(18);
      for (final type in [...TypeRules.iosReadOnly, ...TypeRules.characteristics, HealthDataType.SLEEP_UNKNOWN]) {
        expect(catalog.isReadOnly(type), isTrue, reason: type.name);
        expect(catalog.isWritable(type), isFalse, reason: type.name);
        expect(catalog.isDeletable(type), isFalse, reason: type.name);
      }
      expect(catalog.isWritable(HealthDataType.INSULIN_DELIVERY), isFalse, reason: 'writeInsulinDelivery');
      expect(catalog.isDeletable(HealthDataType.INSULIN_DELIVERY), isTrue);
      expect(catalog.isWritable(HealthDataType.BODY_MASS_INDEX), isTrue);
      expect(catalog.isWritable(HealthDataType.DIETARY_CAFFEINE), isTrue);
    });

    test('interval types leave out the types HealthKit has no statistics for', () {
      final catalog = _iosCatalog(18);
      expect(catalog.intervalTypes, isNot(contains(HealthDataType.WORKOUT)));
      expect(catalog.intervalTypes, contains(HealthDataType.SLEEP_IN_BED));
      expect(catalog.intervalTypes.length, dataTypeKeysIOS.length - TypeRules.iosTypesWithoutIntervals.length);
    });
  });

  group('ordering and grouping', () {
    test('available types are sorted by category, then label', () async {
      final catalog = await _androidCatalog();
      final sorted = [...catalog.available]
        ..sort((a, b) {
          final byCategory = a.category.index.compareTo(b.category.index);
          return byCategory != 0 ? byCategory : a.label.compareTo(b.label);
        });
      expect(catalog.available, sorted);
    });

    test('byCategory partitions the available types in category order', () {
      final catalog = _iosCatalog(18);
      final grouped = catalog.byCategory;
      expect(grouped.values.expand((types) => types).toList(), catalog.available);
      final order = grouped.keys.map((category) => category.index).toList();
      expect(order, [...order]..sort());
      expect(grouped[TypeCategory.characteristics], hasLength(3));
      for (final entry in grouped.entries) {
        expect(entry.value.every((type) => type.category == entry.key), isTrue);
      }
    });

    test('lists are unmodifiable and cached until the capabilities change', () async {
      final catalog = await _androidCatalog();
      expect(() => catalog.available.add(HealthDataType.STEPS), throwsUnsupportedError);
      expect(identical(catalog.available, catalog.available), isTrue);
    });
  });
}
