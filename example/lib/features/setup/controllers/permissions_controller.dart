/// The controller of the Setup page's permissions section: which data types to ask about (the scope and
/// the access) and the plugin's permission calls for them: `requestAuthorization`, `hasPermissions`,
/// `getRequestStatusForAuthorization` (iOS) and `revokePermissions` (Android).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/health/type_category.dart';

import '../models/permission_check.dart';
import '../models/permission_report.dart';
import '../models/permission_request.dart';
import 'permission_checker.dart';
import 'safe_notifier.dart';

/// The per-type answers of one category.
typedef TypeChecks = Map<HealthDataType, PermissionCheck>;

/// Requests, checks and revokes access to the data types of the chosen [scope] with the chosen [access].
///
/// Every call's state is an `AsyncValue`. A new selection is checked at once (where the platform can
/// answer), and answers that arrive for an earlier selection are dropped. While Health Connect's dialog
/// or HealthKit's sheet is open, or permissions are being revoked, the selection cannot change.
class PermissionsController extends ChangeNotifier with SafeNotifier {
  /// Creates the controller for the plugin [health], the device's [capabilities] and its [catalog].
  PermissionsController({required this.health, required this.capabilities, required this.catalog})
    : _checker = PermissionChecker(health, platform: capabilities.platform);

  /// The plugin.
  final Health health;

  /// The platform; refreshed after [revokePermissions], which also takes back Health Connect's history
  /// and background permissions.
  final PlatformCapabilities capabilities;

  /// The data types this device supports, by category: the scopes to choose from.
  final TypeCatalog catalog;

  final PermissionChecker _checker;
  PermissionScope _scope = const PermissionScope.all();
  HealthDataAccess _access = HealthDataAccess.READ_WRITE;
  int _selection = 0; // Counts selection changes, so that answers for an earlier selection are dropped.
  int? _checkedSelection; // The selection the running check answers for.
  Future<void>? _checking; // The running check, which a request or revocation lets finish first.
  int _statusCalls = 0; // Counts request status calls, so that only the latest one's answer shows.
  AsyncValue<bool> _authorization = const AsyncIdle();
  AsyncValue<PermissionReport> _report = const AsyncIdle();
  final Map<TypeCategory, AsyncValue<TypeChecks>> _typeChecks = {};
  AsyncValue<HealthAuthorizationRequestStatus?> _requestStatus = const AsyncIdle();
  AsyncValue<void> _revocation = const AsyncIdle();

  /// The data types to ask about: all supported types or one category.
  PermissionScope get scope => _scope;

  /// The access to ask for: `READ` or `READ_WRITE` (lowered to `READ` for read-only types).
  HealthDataAccess get access => _access;

  /// The types of [scope] with the access planned for each, as the plugin calls take them.
  PermissionRequest get request => PermissionRequest(_scope.typesIn(catalog.byCategory), preferred: _access);

  /// The categories this device has types in: the scopes besides all types.
  List<TypeCategory> get categories => catalog.byCategory.keys.toList();

  /// The result of the last `requestAuthorization` call (see `AuthorizationOutcome`).
  AsyncValue<bool> get authorization => _authorization;

  /// The answers of the last check ([check]), one per category of [scope].
  AsyncValue<PermissionReport> get report => _report;

  /// The answers for each type of [category] ([checkTypesOf]); idle until asked for.
  AsyncValue<TypeChecks> typeChecksOf(TypeCategory category) => _typeChecks[category] ?? const AsyncIdle();

  /// iOS: whether `requestAuthorization` would show HealthKit's sheet for [request].
  AsyncValue<HealthAuthorizationRequestStatus?> get requestStatus => _requestStatus;

  /// The state of the last `revokePermissions` call.
  AsyncValue<void> get revocation => _revocation;

  /// Whether a permission dialog or sheet is open, or permissions are being revoked: the selection is
  /// locked meanwhile, and the check waits until the call is done.
  bool get isRequesting => _authorization.isLoading || _revocation.isLoading;

  /// Whether `hasPermissions` is checking the selection.
  bool get isChecking => _report.isLoading;

  /// Chooses the types to ask about, and checks them.
  void selectScope(PermissionScope scope) {
    if (scope == _scope || isRequesting) return;
    _scope = scope;
    _selectionChanged();
  }

  /// Chooses the access to ask for, and checks it.
  void selectAccess(HealthDataAccess access) {
    if (access == _access || isRequesting) return;
    _access = access;
    _selectionChanged();
  }

  void _selectionChanged() {
    _selection++;
    _authorization = const AsyncIdle();
    _report = const AsyncIdle();
    _typeChecks.clear();
    _requestStatus = const AsyncIdle();
    notifyListeners();
    unawaited(refresh());
  }

  /// Reads the answers for the selection again: the request status on iOS and, where the platform can
  /// answer (Health Connect is available, or this is iOS), the check. Without Health Connect every
  /// check would only fail with the error the platform section explains, so none is made.
  Future<void> refresh() async {
    if (isDisposed) return;
    await Future.wait([refreshRequestStatus(), if (capabilities.healthConnectAvailable) check()]);
  }

  /// Asks the user for [request] with `requestAuthorization`: Health Connect's permission dialog or
  /// HealthKit's sheet. Its result does not say what was granted, so a [check] follows, and on iOS a
  /// [refreshRequestStatus].
  Future<void> requestAuthorization() async {
    if (isRequesting || request.isEmpty) return;
    _authorization = const AsyncLoading();
    notifyListeners();
    // A check that is still running answers for the time before the request: it finishes first, so
    // the check after the request is a new one rather than joining it.
    await _checking;
    // The selection is locked while the request runs, so this is the request the user asked for.
    final asked = request;
    final result = await AsyncValue.guard(() => health.requestAuthorization(asked.types, permissions: asked.accesses));
    _authorization = result;
    notifyListeners();
    if (result is AsyncData<bool>) await Future.wait([check(), refreshRequestStatus()]);
  }

  /// Checks [request] with `hasPermissions`, one call per category of [scope]. The categories whose types
  /// were checked one by one ([checkTypesOf]) are checked again with it, as is the category of a scope of
  /// one category, so open categories never show answers older than the report.
  ///
  /// A check of the same selection that is already running is not repeated, and none starts while
  /// [isRequesting]: the request or revocation checks when it is done.
  Future<void> check() {
    if (isRequesting || _checkedSelection == _selection) return _checking ?? Future.value();
    final check = _check(_selection);
    _checking = check;
    return check.whenComplete(() {
      if (identical(_checking, check)) _checking = null;
    });
  }

  Future<void> _check(int selection) async {
    _checkedSelection = selection;
    final (scope, access) = (_scope, _access);
    final groups = catalog.byCategory;
    final categories = scope.categoriesIn(groups);
    final reopened = {..._typeChecks.keys, if (categories.length == 1) categories.single};
    _report = _report.toLoading();
    _typeChecks.updateAll((category, checks) => checks.toLoading());
    notifyListeners();
    final result = await AsyncValue.guard(() async {
      final checks = await Future.wait([
        for (final category in categories) _checker.check(PermissionRequest(groups[category]!, preferred: access)),
      ]);
      return PermissionReport(
        scope: scope,
        access: access,
        categories: {for (var i = 0; i < categories.length; i++) categories[i]: checks[i]},
        checkedAt: DateTime.now(),
      );
    });
    // Dropped when the user chose another selection meanwhile, which is checked on its own.
    if (selection != _selection) return;
    _checkedSelection = null;
    _report = result;
    final report = result.valueOrNull;
    _typeChecks.removeWhere((category, _) => report == null || !report.categories.containsKey(category));
    notifyListeners();
    if (result is AsyncData<PermissionReport>) {
      await Future.wait([
        for (final category in reopened)
          if (result.value.categories.containsKey(category)) _checkTypes(category, result),
      ]);
    }
  }

  /// Checks each type of [category] on its own with `hasPermissions`, to show which are missing. Needs a
  /// completed [check]: the types are checked with the access of its report.
  Future<void> checkTypesOf(TypeCategory category) async {
    final report = _report;
    if (report is! AsyncData<PermissionReport> || typeChecksOf(category).isLoading) return;
    await _checkTypes(category, report);
  }

  /// Checks each type of [category] for [report], keeping the previous answers while the calls run.
  Future<void> _checkTypes(TypeCategory category, AsyncData<PermissionReport> report) async {
    _typeChecks[category] = typeChecksOf(category).toLoading();
    notifyListeners();
    final request = PermissionRequest(catalog.byCategory[category] ?? const [], preferred: report.value.access);
    final result = await AsyncValue.guard(() => _checker.checkEach(request));
    // Dropped when a newer check, or another selection, replaced the report these answers belong to.
    if (!identical(_report, report)) return;
    _typeChecks[category] = result;
    notifyListeners();
  }

  /// iOS: asks `getRequestStatusForAuthorization` whether requesting [request] would show the sheet.
  /// Nothing to do on Android, where the plugin returns null. Only the latest call's answer is kept.
  Future<void> refreshRequestStatus() async {
    if (!capabilities.isIOS) return;
    final call = ++_statusCalls;
    final request = this.request;
    _requestStatus = _requestStatus.toLoading();
    notifyListeners();
    final result = request.isEmpty
        ? const AsyncData<HealthAuthorizationRequestStatus?>(null)
        : await AsyncValue.guard(
            () => health.getRequestStatusForAuthorization(request.types, permissions: request.accesses),
          );
    if (call != _statusCalls) return;
    _requestStatus = result;
    notifyListeners();
  }

  /// Android: takes back every Health Connect permission of the app with `revokePermissions`, then
  /// refreshes the capabilities and checks again. Health Connect applies it fully only once the app has
  /// been restarted, so the answers may lag behind until then.
  Future<void> revokePermissions() async {
    if (!capabilities.isAndroid || isRequesting) return;
    _revocation = const AsyncLoading();
    notifyListeners();
    await _checking;
    // The plugin only logs a failure of Health Connect here, so the call completes either way.
    final result = await AsyncValue.guard(health.revokePermissions);
    // Revoking also takes back the history and background permissions that the capabilities show.
    await capabilities.refresh();
    _revocation = result;
    notifyListeners();
    if (result is AsyncData<void> && capabilities.healthConnectAvailable) await check();
  }
}
