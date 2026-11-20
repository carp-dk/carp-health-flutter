import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_category.dart';

void main() {
  group('every HealthDataType', () {
    for (final type in HealthDataType.values) {
      test('${type.name} has a label, category, icon and the plugin default unit', () {
        expect(type.label.trim(), isNotEmpty);
        expect(type.label, isNot(contains('_')), reason: 'labels are words, not enum names');
        expect(TypeCategory.values, contains(type.category));
        expect(type.icon.codePoint, isPositive);
        expect(dataTypeToUnit, contains(type), reason: 'the plugin has a default unit for every type');
        expect(type.defaultUnit, dataTypeToUnit[type]);
      });
    }
  });

  test('labels are unique, so pickers and lists can tell types apart', () {
    final labels = HealthDataType.values.map((type) => type.label).toList();
    expect(labels.toSet(), hasLength(labels.length));
  });

  test('every category holds at least one type', () {
    final used = HealthDataType.values.map((type) => type.category).toSet();
    expect(used, containsAll(TypeCategory.values));
  });

  test('categories have labels and icons', () {
    for (final category in TypeCategory.values) {
      expect(category.label, isNotEmpty);
      expect(category.icon.codePoint, isPositive);
    }
  });

  test('a few spot checks', () {
    expect(HealthDataType.HEART_RATE.label, 'Heart rate');
    expect(HealthDataType.HEART_RATE.category, TypeCategory.vitals);
    expect(HealthDataType.SLEEP_REM.category, TypeCategory.sleep);
    expect(HealthDataType.DIETARY_IRON.category, TypeCategory.nutrition);
    expect(HealthDataType.HEADACHE_SEVERE.category, TypeCategory.symptoms);
    expect(HealthDataType.STEPS.defaultUnit, HealthDataUnit.COUNT);
    // Types without an icon of their own take their category's.
    expect(HealthDataType.DIETARY_IRON.icon, TypeCategory.nutrition.icon);
  });
}
