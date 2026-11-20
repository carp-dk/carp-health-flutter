/// Runs the Write page's sample data: the [SampleDataPlan]'s writes one after the other, each with its
/// own result, and the `requestAuthorization` call that grants them write access.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/permission_plan.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/writes/recent_writes.dart';

import '../forms/common/write_outcome.dart';
import 'sample_data_plan.dart';
import 'sample_step.dart';

/// How a run of the sample data went: how many steps saved their data, returned false, threw, were
/// skipped on this device or did not run (cancelled).
typedef SampleDataSummary = ({int saved, int notSaved, int failed, int skipped, int notRun});

/// The state of the sample data and its plugin calls.
///
/// [run] writes the runnable steps in order, each through `AsyncValue.guard`: a step that throws is
/// marked failed and the next one runs, so one missing permission does not stop the others. Each saved
/// write is added to [recentWrites]. [cancel] stops the run after the step that is running (a plugin
/// call cannot be taken back). Nothing here throws at the UI.
class SampleDataController extends ChangeNotifier {
  /// Creates the controller, writing through [health] on the device [capabilities] describes; [clock]
  /// gives the time the writes end at (now by default).
  SampleDataController({
    required this.health,
    required this.capabilities,
    required this.recentWrites,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _steps = _plan();
  }

  /// The plugin.
  final Health health;

  /// The platform, which decides the steps that run.
  final PlatformCapabilities capabilities;

  /// Where saved writes are logged.
  final RecentWrites recentWrites;

  final DateTime Function() _clock;
  late List<SampleStep> _steps;
  List<AsyncValue<WriteOutcome>> _results = const [];
  List<String?>? _skips;
  AsyncValue<bool> _access = const AsyncIdle();
  bool _running = false;
  bool _cancelling = false;
  bool _disposed = false;

  /// The steps of the plan, in order.
  List<SampleStep> get steps => _steps;

  /// Whether a run is going on.
  bool get isRunning => _running;

  /// Whether the running run will stop after its current step.
  bool get isCancelling => _cancelling;

  /// Whether a run has started since the plan was last reset.
  bool get hasRun => _results.isNotEmpty;

  /// The result of step [index]: idle until it runs (or when it was skipped or cancelled), loading while
  /// it runs, then what it returned or threw.
  AsyncValue<WriteOutcome> resultOf(int index) => index < _results.length ? _results[index] : const AsyncIdle();

  /// Why step [index] is skipped on this device, or null when it runs. During and after a run, the
  /// reasons the run started with.
  String? skipReasonOf(int index) => _skips?[index] ?? (_skips == null ? _steps[index].skipReason(capabilities) : null);

  /// The steps this device runs.
  int get runnableCount => List.generate(_steps.length, skipReasonOf).where((reason) => reason == null).length;

  /// The steps of the current or last run that finished.
  int get finishedCount => _results.where((result) => result is AsyncData || result is AsyncError).length;

  /// The progress of the current or last run, from 0 to 1.
  double get progress => runnableCount == 0 ? 0 : finishedCount / runnableCount;

  /// The step running now, or null.
  SampleStep? get currentStep {
    final index = _results.indexWhere((result) => result.isLoading);
    return index < 0 ? null : _steps[index];
  }

  /// The counts of the current or last run.
  SampleDataSummary get summary {
    var saved = 0, notSaved = 0, failed = 0, skipped = 0, notRun = 0;
    for (var i = 0; i < _steps.length; i++) {
      if (skipReasonOf(i) != null) {
        skipped++;
        continue;
      }
      switch (resultOf(i)) {
        case AsyncData(:final value):
          value.success ? saved++ : notSaved++;
        case AsyncError():
          failed++;
        case AsyncIdle() || AsyncLoading():
          notRun++;
      }
    }
    return (saved: saved, notSaved: notSaved, failed: failed, skipped: skipped, notRun: notRun);
  }

  /// The types whose write access the runnable steps need.
  List<HealthDataType> get accessTypes => SampleDataPlan.accessTypes(_steps, capabilities);

  /// The state of the last [requestAccess]: its data is what `requestAuthorization` returned.
  AsyncValue<bool> get access => _access;

  /// Writes the runnable steps one by one, with a fresh plan ending now. Does nothing while a run is
  /// going on.
  Future<void> run() async {
    if (_running) return;
    _steps = _plan();
    _skips = [for (final step in _steps) step.skipReason(capabilities)];
    _results = List.filled(_steps.length, const AsyncIdle());
    _running = true;
    _cancelling = false;
    _notify();
    for (var i = 0; i < _steps.length; i++) {
      if (_disposed || _cancelling) break;
      if (_skips![i] != null) continue;
      final step = _steps[i];
      _setResult(i, const AsyncLoading());
      final result = await AsyncValue.guard(() => step.write(health));
      if (_disposed) return;
      _setResult(i, result);
      if (result case AsyncData(value: final outcome) when outcome.success) {
        recentWrites.add(
          RecentWrite(
            type: outcome.type,
            description: outcome.description,
            uuid: outcome.uuid,
            clientRecordId: outcome.clientRecordId,
          ),
        );
      }
    }
    _running = false;
    _cancelling = false;
    _notify();
  }

  /// Stops the run after the step that is running.
  void cancel() {
    if (!_running || _cancelling) return;
    _cancelling = true;
    _notify();
  }

  /// Forgets the last run's results, back to the plan for the current capabilities.
  void reset() {
    if (_running) return;
    _steps = _plan();
    _results = const [];
    _skips = null;
    _notify();
  }

  /// Asks for read and write access to [accessTypes] with `requestAuthorization`; [PermissionPlan]
  /// asks only for read access where write access cannot be requested. Never throws.
  ///
  /// On Android `true` means that at least one permission is granted; on iOS only that HealthKit
  /// handled the request (it does not tell whether the user allowed writing).
  Future<void> requestAccess() async {
    if (_access.isLoading) return;
    final types = accessTypes;
    _access = const AsyncLoading();
    _notify();
    final result = await AsyncValue.guard(
      () => health.requestAuthorization(types, permissions: PermissionPlan.accessesFor(types)),
    );
    _access = result;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<SampleStep> _plan() =>
      SampleDataPlan.build(platform: capabilities.platform ?? HealthPlatformType.googleHealthConnect, now: _clock());

  void _setResult(int index, AsyncValue<WriteOutcome> result) {
    _results = [..._results]..[index] = result;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
