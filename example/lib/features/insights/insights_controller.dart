/// The state and plugin calls of the Insights page: `getHealthIntervalDataFromTypes` for one type over
/// a range, in buckets of an hour, a day or a week, and `getTotalStepsInInterval` over the same range.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';

import 'model/insights_options.dart';
import 'model/interval_filtering.dart';
import 'model/interval_series.dart';
import 'model/steps_total.dart';

/// Reads the intervals of the chosen [type] ([series]) and the step total ([steps]) whenever an
/// option changes, each read guarded (failures become [AsyncError]s) and only the newest read of
/// each kind kept, so a slow read cannot overwrite a newer one. Also holds the bucket selected in the
/// chart ([selected]).
class InsightsController extends ChangeNotifier {
  /// Creates the controller for the plugin [health], offering the interval types of [catalog].
  /// [clock] gives the current time, at which the ranges end (tests pin it).
  InsightsController({required this.health, required this.catalog, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final types = catalog.intervalTypes;
    _type = types.contains(preferredType) ? preferredType : (types.isEmpty ? null : types.first);
  }

  /// The plugin instance every call goes through.
  final Health health;

  /// The data types of this device; [types] are its interval types.
  final TypeCatalog catalog;

  /// The type read first: steps, as in the README's example, where the platform has it.
  static const HealthDataType preferredType = HealthDataType.STEPS;

  final DateTime Function() _clock;
  HealthDataType? _type;
  InsightsInterval _interval = InsightsInterval.day;
  InsightsRange _range = InsightsRange.last7Days;
  bool _excludeManual = false;
  bool _includeManualSteps = true;
  int? _selected;
  AsyncValue<IntervalSeries> _series = const AsyncIdle();
  AsyncValue<StepsTotal> _steps = const AsyncIdle();
  int _seriesGeneration = 0;
  int _stepsGeneration = 0;
  bool _disposed = false;

  /// The platform and its features.
  PlatformCapabilities get capabilities => catalog.capabilities;

  /// The platform the reads run on (Health Connect where the plugin has none).
  HealthPlatformType get platform => capabilities.platform ?? HealthPlatformType.googleHealthConnect;

  /// The types `getHealthIntervalDataFromTypes` aggregates on this device (`TypeCatalog.intervalTypes`).
  List<HealthDataType> get types => catalog.intervalTypes;

  /// The type read, or null where the platform has no interval types.
  HealthDataType? get type => _type;

  /// The length of the buckets: the `interval` argument.
  InsightsInterval get interval => _interval;

  /// How far back the reads go.
  InsightsRange get range => _range;

  /// Whether the interval read filters `RecordingMethod.manual` (`recordingMethodsToFilter`).
  bool get excludeManual => _excludeManual;

  /// Whether leaving out manual entries works for [type] on this platform ([IntervalFiltering]).
  bool get manualFilterApplies => switch (_type) {
    final type? => IntervalFiltering.canLeaveOutManual(type, platform),
    null => false,
  };

  /// The `includeManualEntry` argument of the step total.
  bool get includeManualSteps => _includeManualSteps;

  /// The index of the selected bucket, or null.
  int? get selected => _selected;

  /// The selected bucket of the current [series], or null.
  IntervalBucket? get selectedBucket {
    final index = _selected;
    final buckets = _series.valueOrNull?.buckets;
    return index == null || buckets == null || index >= buckets.length ? null : buckets[index];
  }

  /// The intervals of [type] (`getHealthIntervalDataFromTypes`).
  AsyncValue<IntervalSeries> get series => _series;

  /// The step total over [range] (`getTotalStepsInInterval`).
  AsyncValue<StepsTotal> get steps => _steps;

  /// Reads the intervals and the step total. Never throws.
  Future<void> load() => Future.wait([loadSeries(), loadSteps()]);

  /// Reads [type]'s intervals over [range] in buckets of [interval], leaving out manual entries where
  /// [excludeManual] asks (and the platform can). Clears the selection. Never throws.
  Future<void> loadSeries() async {
    final type = _type;
    if (type == null) return;
    final generation = ++_seriesGeneration;
    final range = _range.at(_clock());
    final seconds = _interval.seconds;
    final filter = IntervalFiltering.filterFor(excludeManual: _excludeManual);
    final platform = this.platform;
    _series = _series.toLoading();
    _notify();
    final result = await AsyncValue.guard(() async {
      final points = await health.getHealthIntervalDataFromTypes(
        startDate: range.start,
        endDate: range.end,
        types: [type],
        interval: seconds,
        recordingMethodsToFilter: filter,
      );
      return IntervalSeries.fromPoints(
        type: type,
        points: points,
        start: range.start,
        end: range.end,
        intervalSeconds: seconds,
        platform: platform,
      );
    });
    if (_disposed || generation != _seriesGeneration) return;
    _series = result;
    _selected = null;
    _notify();
  }

  /// Counts the steps over [range] with `getTotalStepsInInterval`, with or without manual entries
  /// ([includeManualSteps]). Never throws.
  Future<void> loadSteps() async {
    final generation = ++_stepsGeneration;
    final range = _range.at(_clock());
    final includeManualEntry = _includeManualSteps;
    _steps = _steps.toLoading();
    _notify();
    final result = await AsyncValue.guard(() async {
      final steps = await health.getTotalStepsInInterval(
        range.start,
        range.end,
        includeManualEntry: includeManualEntry,
      );
      return StepsTotal(steps: steps, range: range, includeManualEntry: includeManualEntry);
    });
    if (_disposed || generation != _stepsGeneration) return;
    _steps = result;
    _notify();
  }

  /// Reads the intervals of [type] instead.
  Future<void> selectType(HealthDataType type) async {
    if (type == _type) return;
    _type = type;
    await loadSeries();
  }

  /// Reads in buckets of [interval] instead. Where they would not fit the range (hours over more than
  /// a day), the range shrinks to the longest that fits, and the step total follows it.
  Future<void> selectInterval(InsightsInterval interval) async {
    if (interval == _interval) return;
    _interval = interval;
    if (interval.fitsIn(_range)) return loadSeries();
    _range = InsightsRange.values.lastWhere(interval.fitsIn);
    await load();
  }

  /// Reads over [range] instead. Where the buckets would not fit it, they grow to the shortest that
  /// fits (days instead of hours).
  Future<void> selectRange(InsightsRange range) async {
    if (range == _range) return;
    _range = range;
    if (!_interval.fitsIn(range)) _interval = InsightsInterval.values.firstWhere((each) => each.fitsIn(range));
    await load();
  }

  /// Leaves manual entries out of the intervals, or includes them again.
  Future<void> setExcludeManual(bool exclude) async {
    if (exclude == _excludeManual) return;
    _excludeManual = exclude;
    await loadSeries();
  }

  /// Counts the steps with or without manual entries.
  Future<void> setIncludeManualSteps(bool include) async {
    if (include == _includeManualSteps) return;
    _includeManualSteps = include;
    await loadSteps();
  }

  /// Selects bucket [index] of the current [series], or clears the selection for null.
  void select(int? index) {
    if (index == _selected) return;
    _selected = index;
    _notify();
  }

  /// What tapping a bar does: selects bucket [index], or clears the selection when [index] is selected
  /// already or null (a tap beside the bars).
  void toggle(int? index) => select(index == _selected ? null : index);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
