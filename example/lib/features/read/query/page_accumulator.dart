/// Collects the pages of a `Health.getHealthDataPages` read as they arrive, the way an app that processes
/// a large read page by page would: it counts every point but keeps only the last ones of each type.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'query_options.dart';
import 'query_result.dart';

/// How far a page by page read has come, for the progress card.
@immutable
class QueryProgress {
  /// Creates a progress report.
  const QueryProgress({
    required this.pages,
    required this.points,
    required this.typesDone,
    required this.typesTotal,
    this.currentType,
  });

  /// The pages delivered so far.
  final int pages;

  /// The points in those pages.
  final int points;

  /// The types whose last page (`HealthDataPage.isLastPageForType`) has arrived.
  final int typesDone;

  /// The types the read covers.
  final int typesTotal;

  /// The type of the latest page, or null before the first page.
  final HealthDataType? currentType;

  /// The share of types done, for a determinate progress bar; null (indeterminate) for a read of one type,
  /// as the plugin cannot know how many pages a type has before it has read them.
  double? get fraction => typesTotal > 1 ? typesDone / typesTotal : null;
}

/// Adds up the pages of one `getHealthDataPages` read ([add]) and turns them into a [QueryResult] ([build]).
///
/// Memory stays bounded however much data the read returns: every point is counted, but only the last
/// [keepPerType] points of each type are kept, as the README advises (process each page and let it go).
class PageAccumulator {
  /// Creates an accumulator for a read of [types], keeping [keepPerType] points of each type.
  PageAccumulator(List<HealthDataType> types, {this.keepPerType = defaultKeepPerType})
    : types = List.unmodifiable(types);

  /// How many points of each type the example keeps by default.
  static const int defaultKeepPerType = 1000;

  /// The types the read covers, in the order it reads them.
  final List<HealthDataType> types;

  /// The most points kept of each type: the last ones read.
  final int keepPerType;

  // In the order the types were read, which is the order the plugin reads them in.
  final Map<HealthDataType, List<HealthDataPoint>> _kept = {};
  final Map<HealthDataType, int> _counts = {};
  final Set<HealthDataType> _readPermissionDenied = {};
  final Set<HealthDataType> _done = {};
  int _pages = 0;
  int _points = 0;
  HealthDataType? _currentType;

  /// The pages added so far.
  int get pages => _pages;

  /// The points in those pages.
  int get points => _points;

  /// The progress of the read so far.
  QueryProgress get progress => QueryProgress(
    pages: _pages,
    points: _points,
    typesDone: _done.length,
    typesTotal: types.length,
    currentType: _currentType,
  );

  /// Adds the next [page] of the read.
  void add(HealthDataPage page) {
    final type = page.type;
    _pages++;
    _points += page.points.length;
    _currentType = type;
    _counts[type] = (_counts[type] ?? 0) + page.points.length;
    // Android sets this on every page of a type read without its read permission; never on iOS.
    if (page.readPermissionDenied) _readPermissionDenied.add(type);
    // Every type ends with exactly one such page, empty if the type had no more data.
    if (page.isLastPageForType) _done.add(type);

    final kept = _kept.putIfAbsent(type, () => []);
    final fresh = page.points;
    kept.addAll(fresh.length > keepPerType ? fresh.sublist(fresh.length - keepPerType) : fresh);
    if (kept.length > keepPerType) kept.removeRange(0, kept.length - keepPerType);
  }

  /// The result of the pages added so far, read in [elapsed]: after the stream is done, or [cancelled], or
  /// ended by [error] (the pages before an error stay valid).
  QueryResult build({required Duration elapsed, bool cancelled = false, Object? error, StackTrace? stackTrace}) =>
      QueryResult(
        types: types,
        points: [for (final kept in _kept.values) ...kept],
        counts: {for (final type in types) type: 0, ..._counts},
        mode: QueryMode.pages,
        elapsed: elapsed,
        pages: _pages,
        readPermissionDenied: _readPermissionDenied,
        cancelled: cancelled,
        error: error,
        stackTrace: stackTrace,
      );
}
