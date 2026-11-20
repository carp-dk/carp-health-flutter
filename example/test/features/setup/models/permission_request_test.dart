import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/features/setup/models/permission_request.dart';

const _read = HealthDataAccess.READ;
const _write = HealthDataAccess.WRITE;
const _readWrite = HealthDataAccess.READ_WRITE;

void main() {
  group('PermissionScope', () {
    const groups = {
      TypeCategory.activity: [HealthDataType.STEPS, HealthDataType.DISTANCE_DELTA],
      TypeCategory.vitals: [HealthDataType.HEART_RATE],
    };

    test('all types covers every category, in catalog order', () {
      const scope = PermissionScope.all();

      expect(scope.isAll, isTrue);
      expect(scope.label, 'All types');
      expect(scope.categoriesIn(groups), [TypeCategory.activity, TypeCategory.vitals]);
      expect(scope.typesIn(groups), [HealthDataType.STEPS, HealthDataType.DISTANCE_DELTA, HealthDataType.HEART_RATE]);
    });

    test('a category covers its own types, and nothing where the device has none', () {
      const vitals = PermissionScope.category(TypeCategory.vitals);

      expect(vitals.isAll, isFalse);
      expect(vitals.label, TypeCategory.vitals.label);
      expect(vitals.typesIn(groups), [HealthDataType.HEART_RATE]);
      expect(const PermissionScope.category(TypeCategory.sleep).categoriesIn(groups), isEmpty);
      expect(const PermissionScope.category(TypeCategory.sleep).typesIn(groups), isEmpty);
    });

    test('scopes are equal when they cover the same category', () {
      expect(const PermissionScope.category(TypeCategory.sleep), const PermissionScope.category(TypeCategory.sleep));
      expect(
        const PermissionScope.category(TypeCategory.sleep).hashCode,
        const PermissionScope.category(TypeCategory.sleep).hashCode,
      );
      expect(const PermissionScope.all(), isNot(const PermissionScope.category(TypeCategory.sleep)));
    });
  });

  group('PermissionRequest', () {
    test('asks for read and write, and only to read where write access cannot be requested', () {
      // HealthKit only lets apps read ECGs, characteristics can only be read, and no method writes power.
      final request = PermissionRequest([
        HealthDataType.STEPS,
        HealthDataType.ELECTROCARDIOGRAM,
        HealthDataType.GENDER,
        HealthDataType.POWER,
      ], preferred: _readWrite);

      expect(request.length, 4);
      expect(request.isEmpty, isFalse);
      expect(request.accesses, [_readWrite, _read, _read, _read]);
      expect(request.readOnlyTypes, [HealthDataType.ELECTROCARDIOGRAM, HealthDataType.GENDER, HealthDataType.POWER]);
      expect(request.accessOf(HealthDataType.STEPS), _readWrite);
      expect(request.accessOf(HealthDataType.WEIGHT), isNull);
    });

    test('asks only to read every type when read is chosen, so none is read only by exception', () {
      final request = PermissionRequest([HealthDataType.STEPS, HealthDataType.GENDER], preferred: _read);

      expect(request.accesses, [_read, _read]);
      expect(request.readOnlyTypes, isEmpty);
    });

    test('keeps the planned access of the types it is narrowed to', () {
      final request = PermissionRequest([
        HealthDataType.STEPS,
        HealthDataType.ELECTROCARDIOGRAM,
        HealthDataType.HEART_RATE,
      ], preferred: _readWrite);

      final narrowed = request.where((type) => type != HealthDataType.STEPS);
      expect(narrowed.types, [HealthDataType.ELECTROCARDIOGRAM, HealthDataType.HEART_RATE]);
      expect(narrowed.accesses, [_read, _readWrite]);
      expect(narrowed.preferred, _readWrite);

      final one = request.only(HealthDataType.ELECTROCARDIOGRAM);
      expect(one.types, [HealthDataType.ELECTROCARDIOGRAM]);
      expect(one.accesses, [_read]);
      expect(request.only(HealthDataType.WEIGHT).isEmpty, isTrue);
    });

    test('asks for write access alone to the types that can be written', () {
      final request = PermissionRequest([
        HealthDataType.STEPS,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.BLOOD_TYPE,
        HealthDataType.WEIGHT,
      ], preferred: _readWrite);

      final write = request.writeOnly();
      expect(write.types, [HealthDataType.STEPS, HealthDataType.WEIGHT]);
      expect(write.accesses, [_write, _write]);
      expect(write.preferred, _write);
    });

    test('its lists cannot be changed, and requests with the same lists are equal', () {
      final request = PermissionRequest([HealthDataType.STEPS], preferred: _read);

      expect(() => request.types.add(HealthDataType.WEIGHT), throwsUnsupportedError);
      expect(() => request.accesses.add(_read), throwsUnsupportedError);
      expect(request, PermissionRequest([HealthDataType.STEPS], preferred: _read));
      expect(request.hashCode, PermissionRequest([HealthDataType.STEPS], preferred: _read).hashCode);
      expect(request, isNot(PermissionRequest([HealthDataType.STEPS], preferred: _readWrite)));
    });

    test('names each access', () {
      expect(_read.label, 'Read');
      expect(_write.label, 'Write');
      expect(_readWrite.label, 'Read & write');
    });
  });
}
