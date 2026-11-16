/// The state and plugin calls of Read > Query: reading data points all at once with
/// `Health.getHealthDataFromTypes`, or page by page with `Health.getHealthDataPages` (a cancellable
/// stream), and tidying the result with `Health.removeDuplicates`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/settings/plugin_settings.dart';

import 'page_accumulator.dart';
import 'query_options.dart';
import 'query_result.dart';

/// Holds the query's [options], runs the reads and exposes their [result]; the Query section listens.
class QueryController extends ChangeNotifier {
  /// Creates the controller, reading through [health] with the page size of [settings] and starting from
  /// [QueryOptions.initial] for the [available] types.
  QueryController({required this.health, required this.settings, required List<HealthDataType> available})
    : _options = QueryOptions.initial(available);

  /// The plugin instance the reads go through.
  final Health health;

  /// The plugin settings; page by page reads use their `pageSize`.
  final PluginSettings settings;

  QueryOptions _options;
  AsyncValue<QueryResult> _result = const AsyncIdle();
  _PagedRead? _paged;
  bool _disposed = false;

  /// What to read and how.
  QueryOptions get options => _options;

  /// The state of the last read: its [QueryResult], or the error that failed it.
  AsyncValue<QueryResult> get result => _result;

  /// How far a running page by page read has come; null otherwise.
  QueryProgress? get progress => _paged?.accumulator.progress;

  /// How long a running page by page read has taken so far; null otherwise.
  Duration? get readingFor => _paged?.stopwatch.elapsed;

  /// Whether a read is running.
  bool get isReading => _result.isLoading;

  /// Whether a running page by page read is being cancelled (waiting for the call in flight).
  bool get isCancelling => _paged?.cancelling ?? false;

  /// Whether a read can start: none is running and some types are chosen.
  bool get canRead => !isReading && _options.types.isNotEmpty;

  /// Replaces the options; the next [read] uses them.
  set options(QueryOptions options) {
    _options = options;
    _notify();
  }

  /// Reads with the current [options], and completes when the read has ended: done, failed or cancelled.
  /// Never throws: failures become an [AsyncError] (or, page by page, a result that keeps its error).
  Future<void> read() async {
    if (!canRead) return;
    // A preset such as "Last hour" means the hour before this read, not before the preset was picked.
    final options = _options = _options.copyWith(range: _options.range.refreshed());
    final previous = options.appendResults ? _result.valueOrNull : null;
    _result = AsyncLoading(previous: previous);
    _notify();
    switch (options.mode) {
      case QueryMode.allAtOnce:
        await _readAllAtOnce(options, previous);
      case QueryMode.pages:
        await _readPages(options, previous);
    }
  }

  /// Cancels a running page by page read by cancelling its stream subscription: the plugin then makes no
  /// further platform call, and `cancel()` completes once the call in flight has returned (its page is
  /// dropped). The pages read before stay as the result, marked cancelled.
  Future<void> cancel() async {
    final paged = _paged;
    if (paged == null || paged.cancelling) return;
    paged.cancelling = true;
    _notify();
    await paged.subscription.cancel();
    _finishPages(paged, cancelled: true);
  }

  /// Removes duplicate points from the result with `removeDuplicates`, which keeps the first of points that
  /// are equal in every field (`HealthDataPoint ==`, metadata included).
  void removeDuplicates() {
    if (_result case AsyncData(value: final result)) {
      _setResult(result.withoutDuplicates(health.removeDuplicates(result.points)));
    }
  }

  /// Shows the result's points in [order].
  void sortBy(SortOrder order) {
    if (_result case AsyncData(value: final result)) _setResult(result.sortedBy(order));
  }

  /// Drops [point] from the result, for example after the data point sheet deleted it.
  void removePoint(HealthDataPoint point) {
    if (_result case AsyncData(value: final result)) _setResult(result.without(point));
  }

  /// Forgets the result. Does nothing while a read runs.
  void clear() {
    if (isReading) return;
    _result = const AsyncIdle();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    // Nothing listens for the end of a running read any more: stop it, and let read() return.
    if (_paged case final paged?) {
      _paged = null;
      unawaited(paged.subscription.cancel());
      if (!paged.done.isCompleted) paged.done.complete();
    }
    super.dispose();
  }

  /// `getHealthDataFromTypes`: one call that returns every point of the range, or with a `limit` the
  /// newest points of each type.
  Future<void> _readAllAtOnce(QueryOptions options, QueryResult? previous) async {
    final types = options.orderedTypes;
    final result = await AsyncValue.guard(() async {
      final stopwatch = Stopwatch()..start();
      final points = await health.getHealthDataFromTypes(
        types: types,
        startTime: options.range.start,
        endTime: options.range.end,
        preferredUnits: options.preferredUnits,
        recordingMethodsToFilter: options.recordingMethodsToFilter.toList(),
        limit: options.effectiveLimit,
      );
      final read = QueryResult.fromList(types, points, elapsed: stopwatch.elapsed, limit: options.effectiveLimit);
      return previous == null ? read : previous.followedBy(read);
    });
    if (_disposed) return;
    _result = result;
    _notify();
  }

  /// `getHealthDataPages`: listens to the stream of pages and adds them up as they arrive. The returned
  /// future completes when the stream ends or is cancelled.
  Future<void> _readPages(QueryOptions options, QueryResult? previous) {
    final types = options.orderedTypes;
    final paged = _PagedRead(PageAccumulator(types), previous);
    _paged = paged;
    final pages = health.getHealthDataPages(
      types: types,
      startTime: options.range.start,
      endTime: options.range.end,
      preferredUnits: options.preferredUnits,
      recordingMethodsToFilter: options.recordingMethodsToFilter.toList(),
      // Without it the plugin reads Health.pageSize, which PluginSettings sets too: passing it shows the
      // per-read override.
      pageSize: settings.pageSize,
    );
    // listen rather than `await for`, to keep the subscription that Cancel cancels. The plugin's stream
    // reports argument errors (such as an invalid pageSize) as stream errors too.
    paged.subscription = pages.listen(
      (page) {
        paged.accumulator.add(page);
        _notify();
      },
      onError: (Object error, StackTrace stackTrace) => _finishPages(paged, error: error, stackTrace: stackTrace),
      onDone: () => _finishPages(paged),
      cancelOnError: true,
    );
    return paged.done.future;
  }

  /// Ends the page by page read [paged]: its pages become the result, also after a cancel or an error (an
  /// error ends the stream, but the pages delivered before it stay valid).
  void _finishPages(_PagedRead paged, {bool cancelled = false, Object? error, StackTrace? stackTrace}) {
    if (!identical(_paged, paged)) return;
    _paged = null;
    paged.stopwatch.stop();
    if (!paged.done.isCompleted) paged.done.complete();
    if (_disposed) return;
    final accumulator = paged.accumulator;
    if (error != null && accumulator.pages == 0) {
      _result = AsyncError(error, stackTrace ?? StackTrace.current);
    } else {
      final read = accumulator.build(
        elapsed: paged.stopwatch.elapsed,
        cancelled: cancelled,
        error: error,
        stackTrace: stackTrace,
      );
      _result = AsyncData(paged.previous == null ? read : paged.previous!.followedBy(read));
    }
    _notify();
  }

  void _setResult(QueryResult result) {
    _result = AsyncData(result);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

/// A running page by page read: its subscription, its pages so far and the result it adds to.
class _PagedRead {
  _PagedRead(this.accumulator, this.previous);

  final PageAccumulator accumulator;

  /// The result the read adds to, when reads add to the result.
  final QueryResult? previous;

  final Stopwatch stopwatch = Stopwatch()..start();

  /// Completes when the read has ended, however it ended.
  final Completer<void> done = Completer<void>();

  late final StreamSubscription<HealthDataPage> subscription;

  bool cancelling = false;
}
