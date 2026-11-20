/// Which access to request for each data type in `requestAuthorization`, `hasPermissions` and
/// `getRequestStatusForAuthorization`, so a request never asks for write access the plugin
/// refuses.
library;

import 'package:health/health.dart';

import 'type_rules.dart';

/// Plans the `permissions` list that goes with a list of types.
///
/// HealthKit lets apps only read some types and raises an exception that crashes the app when
/// write access to one is requested; the plugin therefore throws an `ArgumentError` for `WRITE` or
/// `READ_WRITE` access to them (README, "Authorization on iOS"). Requesting write access to the
/// characteristics fails on iOS too, and no method writes `POWER` or `CYCLING_CADENCE`. The plan
/// asks only for `READ` access to all of these, on both platforms, as none of them is an Android
/// type that could be written.
abstract final class PermissionPlan {
  /// The access to request for [type]: [preferred] (read and write by default), or `READ` where
  /// write access cannot be requested ([canRequestWrite]) or `READ` is preferred.
  static HealthDataAccess accessFor(HealthDataType type, {HealthDataAccess preferred = HealthDataAccess.READ_WRITE}) =>
      preferred == HealthDataAccess.READ || !canRequestWrite(type) ? HealthDataAccess.READ : preferred;

  /// The access for each of [types], in the same order, ready for the `permissions` argument,
  /// which must be as long as `types`.
  static List<HealthDataAccess> accessesFor(
    List<HealthDataType> types, {
    HealthDataAccess preferred = HealthDataAccess.READ_WRITE,
  }) => [for (final type in types) accessFor(type, preferred: preferred)];

  /// Whether write access to [type] may be requested: false for HealthKit's read-only types
  /// ([TypeRules.iosReadOnly]), the characteristics and the types no method writes.
  static bool canRequestWrite(HealthDataType type) =>
      !TypeRules.iosReadOnly.contains(type) &&
      !TypeRules.characteristics.contains(type) &&
      !TypeRules.neverWritten.contains(type);
}
