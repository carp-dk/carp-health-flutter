/// The outcome of one access check of the Setup page: what `hasPermissions` answered for each category
/// of the scope the user chose, and when.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_category.dart';

import 'permission_check.dart';
import 'permission_request.dart';

/// What `hasPermissions` answered for each category of a [PermissionScope], asked with [access].
///
/// One call per category keeps the answers useful: Health Connect answers true only when every type
/// of a call has its permission, so a single call for all types would say little more than "not all".
@immutable
class PermissionReport {
  /// Creates the report of a check of [scope] with [access], made at [checkedAt].
  PermissionReport({
    required this.scope,
    required this.access,
    required Map<TypeCategory, PermissionCheck> categories,
    required this.checkedAt,
  }) : categories = Map.unmodifiable(categories);

  /// The types that were checked.
  final PermissionScope scope;

  /// The access the user chose; read-only types were checked for `READ` (see `PermissionPlan`).
  final HealthDataAccess access;

  /// The answer for each category of [scope], in catalog order.
  final Map<TypeCategory, PermissionCheck> categories;

  /// When the check completed.
  final DateTime checkedAt;

  /// Whether iOS also checked `WRITE` access for some category, the one access HealthKit discloses.
  bool get checkedWrite => categories.values.any((check) => check.write != null);

  /// The number of categories whose [PermissionCheck.effective] answer is [answer].
  int count(PermissionAnswer answer) => categories.values.where((check) => check.effective == answer).length;

  /// The result in one line, such as "9 of 14 categories granted".
  String get summary {
    final total = categories.length;
    final granted = count(PermissionAnswer.granted);
    if (checkedWrite) {
      // Categories without a write answer (only read-only types) cannot count towards it.
      final withWrite = categories.values.where((check) => check.write != null).length;
      return 'Write granted for $granted of $withWrite ${_categories(withWrite)}';
    }
    if (count(PermissionAnswer.unknown) == total) return 'Read access is not disclosed';
    return '$granted of $total ${_categories(total)} granted';
  }

  static String _categories(int count) => count == 1 ? 'category' : 'categories';

  @override
  String toString() => 'PermissionReport(${scope.label}, ${access.name}: $summary)';
}
