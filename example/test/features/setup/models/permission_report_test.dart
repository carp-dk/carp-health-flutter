import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/setup/models/permission_check.dart';
import 'package:health_example/features/setup/models/permission_report.dart';
import 'package:health_example/features/setup/models/permission_request.dart';

const _granted = PermissionCheck(answer: PermissionAnswer.granted);
const _denied = PermissionCheck(answer: PermissionAnswer.denied);
const _unknown = PermissionCheck(answer: PermissionAnswer.unknown);

PermissionReport _report(Map<TypeCategory, PermissionCheck> categories) => PermissionReport(
  scope: const PermissionScope.all(),
  access: HealthDataAccess.READ_WRITE,
  categories: categories,
  checkedAt: DateTime(2026, 11, 17),
);

void main() {
  group('PermissionCheck', () {
    test('turns what hasPermissions returned into an answer', () {
      expect(PermissionAnswer.fromResult(true), PermissionAnswer.granted);
      expect(PermissionAnswer.fromResult(false), PermissionAnswer.denied);
      expect(PermissionAnswer.fromResult(null), PermissionAnswer.unknown);
    });

    test("words Health Connect's answers for a category and for one type", () {
      expect(_granted.describe(isGroup: true).label, 'Granted');
      expect(_granted.describe(isGroup: true).tone, StatusTone.success);
      // Health Connect answers true only when every type of the call has its access.
      expect(_denied.describe(isGroup: true).label, 'Not all granted');
      expect(_denied.describe(isGroup: false).label, 'Not granted');
      expect(_denied.describe(isGroup: false).tone, StatusTone.error);
    });

    test("prefers HealthKit's write answer to the read answer it keeps secret", () {
      const writeGranted = PermissionCheck(answer: PermissionAnswer.unknown, write: PermissionAnswer.granted);
      const writeDenied = PermissionCheck(answer: PermissionAnswer.unknown, write: PermissionAnswer.denied);

      expect(writeGranted.effective, PermissionAnswer.granted);
      expect(writeGranted.describe(isGroup: false).label, 'Write granted');
      expect(writeDenied.effective, PermissionAnswer.denied);
      expect(writeDenied.describe(isGroup: true).label, 'Write not all granted');
      expect(writeDenied.describe(isGroup: true).tone, StatusTone.warning);
      expect(_unknown.effective, PermissionAnswer.unknown);
      expect(_unknown.describe(isGroup: true).label, 'Unknown');
      expect(_unknown.describe(isGroup: true).tone, StatusTone.neutral);
    });

    test('is a value', () {
      expect(const PermissionCheck(answer: PermissionAnswer.unknown, write: PermissionAnswer.granted), isNot(_unknown));
      expect(_denied, const PermissionCheck(answer: PermissionAnswer.denied));
    });
  });

  group('PermissionReport', () {
    test('counts the categories Health Connect granted', () {
      final report = _report({
        TypeCategory.activity: _granted,
        TypeCategory.vitals: _denied,
        TypeCategory.sleep: _granted,
      });

      expect(report.checkedWrite, isFalse);
      expect(report.count(PermissionAnswer.granted), 2);
      expect(report.count(PermissionAnswer.denied), 1);
      expect(report.summary, '2 of 3 categories granted');
      expect(_report({TypeCategory.sleep: _granted}).summary, '1 of 1 category granted');
    });

    test('says when HealthKit disclosed nothing, as for read access', () {
      final report = _report({TypeCategory.activity: _unknown, TypeCategory.vitals: _unknown});

      expect(report.summary, 'Read access is not disclosed');
    });

    test('counts write answers on iOS, among the categories that have one', () {
      final report = _report({
        TypeCategory.activity: const PermissionCheck(answer: PermissionAnswer.unknown, write: PermissionAnswer.granted),
        TypeCategory.vitals: const PermissionCheck(answer: PermissionAnswer.unknown, write: PermissionAnswer.denied),
        // Only read-only types: nothing to ask about writing.
        TypeCategory.characteristics: _unknown,
      });

      expect(report.checkedWrite, isTrue);
      expect(report.count(PermissionAnswer.granted), 1);
      expect(report.count(PermissionAnswer.unknown), 1);
      expect(report.summary, 'Write granted for 1 of 2 categories');
    });

    test('keeps its answers as they were', () {
      final categories = {TypeCategory.activity: _granted};
      final report = _report(categories);
      categories[TypeCategory.vitals] = _denied;

      expect(report.categories.keys, [TypeCategory.activity]);
      expect(() => report.categories[TypeCategory.sleep] = _denied, throwsUnsupportedError);
    });
  });
}
