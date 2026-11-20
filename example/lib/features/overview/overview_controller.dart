/// The state and plugin calls of the Overview page: access to the core data types
/// (`requestAuthorization`, `hasPermissions`, `getRequestStatusForAuthorization`) and today's
/// highlights (`getTotalStepsInInterval`, `getHealthDataFromTypes` with `limit`,
/// `getHealthIntervalDataFromTypes`), read through [HighlightReads].
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/permission_plan.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/writes/recent_writes.dart';

import 'highlight_reads.dart';
import 'model/core_access.dart';
import 'model/highlight.dart';
import 'model/latest_sample.dart';
import 'model/overview_windows.dart';
import 'model/sleep_summary.dart';
import 'model/workout_week.dart';

/// Reads the overview's highlights, each on its own (one failing read leaves the others intact), and
/// checks and requests access to the core types. Every call is guarded: failures become [AsyncError]s.
class OverviewController extends ChangeNotifier {
  /// Creates the controller for the plugin [health] on the device [capabilities] describes.
  ///
  /// With [recentWrites], a write of this app marks the highlights stale, so that [reloadIfStale]
  /// reads them again. [clock] gives the current time (tests pin it).
  OverviewController({required this.health, required this.capabilities, this.recentWrites, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _reads = HighlightReads(health, capabilities) {
    _windows = OverviewWindows(now: _clock());
    recentWrites?.addListener(_markStale);
  }

  /// The plugin instance every call goes through.
  final Health health;

  /// The platform and its status; [refresh] refreshes it too.
  final PlatformCapabilities capabilities;

  /// What this app wrote in this session; a change makes the highlights stale.
  final RecentWrites? recentWrites;

  final DateTime Function() _clock;
  final HighlightReads _reads;
  late OverviewWindows _windows;
  final Map<Highlight, AsyncValue<Object?>> _highlights = {};
  final Map<Highlight, int> _generations = {};
  AsyncValue<CoreAccess> _access = const AsyncIdle();
  int _accessGeneration = 0;
  AsyncValue<bool> _authorization = const AsyncIdle();
  bool _stale = false;
  bool _disposed = false;

  /// The health platform the calls go to (Health Connect where the plugin has none).
  HealthPlatformType get platform => _reads.platform;

  /// The id of this device that read data points carry (`Health.deviceId`), looked up by
  /// `Health.configure`; "unknown" until then.
  String get deviceId => health.deviceId;

  /// The types the hero card's "Grant access" requests: those of every highlight.
  List<HealthDataType> get coreTypes => Highlight.coreTypes(platform);

  /// Whether the plugin can be called: not where it has no platform, nor on Android while Health
  /// Connect is known to be missing or outdated, where every call throws an `UnsupportedError`.
  bool get canRead =>
      capabilities.platform != null &&
      !(capabilities.isAndroid && capabilities.isLoaded && !capabilities.healthConnectAvailable);

  /// The time windows of the last load: "today", "last night" and "this week".
  OverviewWindows get windows => _windows;

  /// The state of [highlight]'s read; the value's type depends on the highlight (see the getters).
  AsyncValue<Object?> highlight(Highlight highlight) => _highlights[highlight] ?? const AsyncIdle();

  /// Today's steps (`getTotalStepsInInterval`).
  AsyncValue<int> get steps => _typed(Highlight.steps);

  /// The newest heart rate of the last 30 days (`getHealthDataFromTypes`, `limit: 1`).
  AsyncValue<LatestSample> get heartRate => _typed(Highlight.heartRate);

  /// The newest weight of the last year (`getHealthDataFromTypes`, `limit: 1`).
  AsyncValue<LatestSample> get weight => _typed(Highlight.weight);

  /// Today's active energy in kcal, null without data (`getHealthIntervalDataFromTypes`).
  AsyncValue<double?> get activeEnergy => _typed(Highlight.activeEnergy);

  /// Last night's sleep (`getHealthIntervalDataFromTypes`).
  AsyncValue<SleepSummary> get sleep => _typed(Highlight.sleep);

  /// This week's workouts (`getHealthDataFromTypes`).
  AsyncValue<WorkoutWeek> get workouts => _typed(Highlight.workouts);

  /// What the platform says about access to the [coreTypes].
  AsyncValue<CoreAccess> get access => _access;

  /// The result of the last `requestAuthorization` ([authorize]).
  AsyncValue<bool> get authorization => _authorization;

  /// Whether an authorization request is running.
  bool get isAuthorizing => _authorization.isLoading;

  /// Whether the access check or any highlight is being read.
  bool get isLoading => _access.isLoading || _highlights.values.any((state) => state.isLoading);

  /// Checks access and reads every highlight, all at once; nothing while [canRead] is false. Never
  /// throws.
  Future<void> load() async {
    _stale = false;
    _windows = OverviewWindows(now: _clock());
    if (!canRead) {
      _notify();
      return;
    }
    await Future.wait([checkAccess(), for (final highlight in Highlight.values) _read(highlight)]);
  }

  /// Pull to refresh: first asks the plugin again for the platform's status and features
  /// (`PlatformCapabilities.refresh`), as Health Connect may have been installed meanwhile, then
  /// reloads. Never throws.
  Future<void> refresh() async {
    await capabilities.refresh();
    await load();
  }

  /// Reloads if this app wrote or deleted something since the last load (see [recentWrites]), for
  /// when the overview is shown again. Never throws.
  Future<void> reloadIfStale() => _stale ? load() : Future<void>.value();

  /// Checks access to the [coreTypes] with the access the hero card requests. Android answers with
  /// `hasPermissions`; iOS, which keeps read access private, with `getRequestStatusForAuthorization`.
  Future<void> checkAccess() async {
    final generation = ++_accessGeneration;
    final types = coreTypes;
    final permissions = PermissionPlan.accessesFor(types);
    _access = _access.toLoading();
    _notify();
    final result = await AsyncValue.guard<CoreAccess>(() async {
      if (capabilities.isIOS) {
        return CoreAccess.fromRequestStatus(
          await health.getRequestStatusForAuthorization(types, permissions: permissions),
        );
      }
      final granted = await health.hasPermissions(types, permissions: permissions);
      return granted == true ? CoreAccess.granted : CoreAccess.missing;
    });
    if (_disposed || generation != _accessGeneration) return;
    _access = result;
    _notify();
  }

  /// Requests read and write access with `requestAuthorization`: to the [coreTypes], or only to the
  /// types of [highlight] when a tile asks. Then checks access again and rereads what the request
  /// covered, as the user's answers change what the reads return.
  Future<void> authorize({Highlight? highlight}) async {
    if (isAuthorizing) return;
    final types = highlight?.typesOn(platform) ?? coreTypes;
    _authorization = _authorization.toLoading();
    _notify();
    // Read and write: write access also puts the app on Health Connect's priority list, whose apps
    // the step and energy sums count (README, "Reading data over intervals").
    final result = await AsyncValue.guard(
      () => health.requestAuthorization(types, permissions: PermissionPlan.accessesFor(types)),
    );
    if (_disposed) return;
    _authorization = result;
    _notify();
    _windows = OverviewWindows(now: _clock());
    await Future.wait([
      checkAccess(),
      if (highlight != null) _read(highlight) else for (final each in Highlight.values) _read(each),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    recentWrites?.removeListener(_markStale);
    super.dispose();
  }

  /// Reads [highlight] over the current [windows].
  Future<void> _read(Highlight highlight) {
    final windows = _windows;
    return switch (highlight) {
      Highlight.steps => _guard<int>(highlight, () => _reads.stepsToday(windows)),
      Highlight.heartRate => _guard(
        highlight,
        () => _reads.latest(HealthDataType.HEART_RATE, windows.heartRateSince, windows.now),
      ),
      Highlight.weight => _guard(
        highlight,
        () => _reads.latest(HealthDataType.WEIGHT, windows.weightSince, windows.now),
      ),
      Highlight.activeEnergy => _guard(
        highlight,
        () => _reads.sum(HealthDataType.ACTIVE_ENERGY_BURNED, windows.startOfToday, windows.now),
      ),
      Highlight.sleep => _guard(highlight, () => _reads.lastNight(windows)),
      Highlight.workouts => _guard(highlight, () => _reads.workoutsThisWeek(windows)),
    };
  }

  /// Runs [read] for [highlight], keeping its previous value on screen while it runs. Only the
  /// newest read of a highlight sets its state, so a slow read cannot overwrite a newer one.
  Future<void> _guard<T>(Highlight highlight, Future<T> Function() read) async {
    final generation = (_generations[highlight] ?? 0) + 1;
    _generations[highlight] = generation;
    final current = _highlights[highlight];
    _highlights[highlight] = current is AsyncValue<T> ? current.toLoading() : AsyncLoading<T>();
    _notify();
    final result = await AsyncValue.guard<T>(read);
    if (_disposed || _generations[highlight] != generation) return;
    _highlights[highlight] = result;
    _notify();
  }

  AsyncValue<T> _typed<T>(Highlight highlight) => switch (_highlights[highlight]) {
    final AsyncValue<T> state => state,
    _ => AsyncIdle<T>(),
  };

  void _markStale() => _stale = true;

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
