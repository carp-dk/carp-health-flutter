/// Asks the plugin's `hasPermissions` about the types of a permission request, in the way each platform
/// can answer it.
library;

import 'package:health/health.dart';
import 'package:health_example/core/health/type_rules.dart';

import '../models/permission_check.dart';
import '../models/permission_request.dart';

/// Checks permission requests with `hasPermissions(types, permissions: accesses)`.
///
/// Health Connect answers true or false, true only when every type of the call has its access. HealthKit
/// keeps read access secret and answers null for `READ` and `READ_WRITE`; it does tell whether the user
/// allowed writing, so on iOS a request that asks for writing is checked for `WRITE` access as well.
class PermissionChecker {
  /// Creates a checker that asks [health], running on [platform].
  const PermissionChecker(this.health, {required this.platform});

  /// The plugin.
  final Health health;

  /// The health platform the app runs on; null where the plugin has none.
  final HealthPlatformType? platform;

  bool get _isIOS => platform == HealthPlatformType.appleHealth;

  /// Checks [request] as a whole: one `hasPermissions` call for the access of each type (and on iOS
  /// one more for `WRITE` access, see [PermissionChecker]). Throws what the plugin throws, such as a
  /// `PlatformException` when Health Connect fails or an `UnsupportedError` when it is missing.
  Future<PermissionCheck> check(PermissionRequest request) async {
    // HealthKit's characteristics are no sample types, and the plugin's iOS side answers false for any
    // type it does not find among those, whatever the user chose. Read access to them is not disclosed
    // either, so the read check leaves them out rather than report them as denied.
    final asked = _isIOS ? request.where((type) => !TypeRules.characteristics.contains(type)) : request;
    final answer = asked.isEmpty
        ? PermissionAnswer.unknown
        : PermissionAnswer.fromResult(await health.hasPermissions(asked.types, permissions: asked.accesses));
    if (!_isIOS || request.preferred == HealthDataAccess.READ) return PermissionCheck(answer: answer);

    final writable = request.writeOnly();
    if (writable.isEmpty) return PermissionCheck(answer: answer);
    final write = await health.hasPermissions(writable.types, permissions: writable.accesses);
    return PermissionCheck(answer: answer, write: PermissionAnswer.fromResult(write));
  }

  /// Checks each type of [request] on its own, as the README advises for finding the types that are
  /// missing: a call for several types only says whether all of them are granted. The calls run at the
  /// same time; in the README's measurements, permission checks did not count against Health Connect's
  /// read quota.
  Future<Map<HealthDataType, PermissionCheck>> checkEach(PermissionRequest request) async {
    final checks = await Future.wait([for (final type in request.types) check(request.only(type))]);
    return {for (var i = 0; i < checks.length; i++) request.types[i]: checks[i]};
  }
}
