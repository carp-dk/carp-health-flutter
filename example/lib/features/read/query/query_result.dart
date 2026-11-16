/// The outcome of a query: the data points read, counted and grouped by type, and what the summary shows
/// about the read (pages, time taken, types read without read permission, ...).
library;

import 'package:health/health.dart';

import '../type_order.dart';
import 'query_options.dart';

/// The order in which the results list shows the points of each type.
enum SortOrder {
  /// The order the plugin returned them in: oldest first in pages and on Android, newest first from
  /// `getHealthDataFromTypes` on iOS, and newest first with a `limit`.
  asReturned('As returned'),

  /// The latest start time first.
  newestFirst('Newest first'),

  /// The earliest start time first.
  oldestFirst('Oldest first');

  const SortOrder(this.label);

  /// The order's name.
  final String label;
}

/// The points of one type in a [QueryResult].
class TypeGroup {
  /// Creates the group of [type].
  const TypeGroup({required this.type, required this.points, required this.count, required this.readPermissionDenied});

  /// The data type.
  final HealthDataType type;

  /// The points kept, in the result's [SortOrder].
  final List<HealthDataPoint> points;

  /// How many points of the type were read, including any not kept.
  final int count;

  /// Whether the type was read without its read permission (Android: only the app's own records).
  final bool readPermissionDenied;

  /// Whether only some of the points read were kept.
  bool get isTruncated => count > points.length;
}

/// What a query read. Immutable: the actions on the results (sorting, removing duplicates, ...) make
/// changed copies.
class QueryResult {
  /// Creates a result; [QueryResult.fromList] and `PageAccumulator.build` make them from plugin replies.
  QueryResult({
    required List<HealthDataType> types,
    required List<HealthDataPoint> points,
    required Map<HealthDataType, int> counts,
    required this.mode,
    required this.elapsed,
    this.limit,
    this.pages,
    Set<HealthDataType> readPermissionDenied = const {},
    this.cancelled = false,
    this.error,
    this.stackTrace,
    this.order = SortOrder.asReturned,
    this.removedDuplicates,
    this.reads = 1,
  }) : types = List.unmodifiable(types),
       points = List.unmodifiable(points),
       counts = Map.unmodifiable(counts),
       readPermissionDenied = Set.unmodifiable(readPermissionDenied);

  /// The result of `getHealthDataFromTypes`, which returns every point it read in one list, so all are kept.
  factory QueryResult.fromList(
    List<HealthDataType> types,
    List<HealthDataPoint> points, {
    required Duration elapsed,
    int? limit,
  }) => QueryResult(
    types: types,
    points: points,
    counts: {for (final type in types) type: 0, ..._countByType(points)},
    mode: QueryMode.allAtOnce,
    elapsed: elapsed,
    limit: limit,
  );

  /// The types asked for, in the order they were read.
  final List<HealthDataType> types;

  /// The points kept, in the order they were read.
  final List<HealthDataPoint> points;

  /// How many points of each type were read, including the points not kept; 0 for a type without data.
  final Map<HealthDataType, int> counts;

  /// How the (last) read was made.
  final QueryMode mode;

  /// How long the (last) read took, from the call until its last point.
  final Duration elapsed;

  /// The `limit` of `getHealthDataFromTypes`, if one was given.
  final int? limit;

  /// The pages `getHealthDataPages` delivered; null for reads all at once.
  final int? pages;

  /// The types whose pages had `HealthDataPage.readPermissionDenied` (Android only).
  final Set<HealthDataType> readPermissionDenied;

  /// Whether the read was cancelled: the points are those of the pages read before.
  final bool cancelled;

  /// The error that ended a page by page read early; the pages before it stay valid.
  final Object? error;

  /// Where [error] was thrown.
  final StackTrace? stackTrace;

  /// The order of the points in [groups].
  final SortOrder order;

  /// How many points the last `removeDuplicates` removed, or null before it ran.
  final int? removedDuplicates;

  /// How many reads this result holds: more than one when reads add to the result.
  final int reads;

  /// How many points were read in all.
  int get total => counts.values.fold(0, (sum, count) => sum + count);

  /// Whether only some of the points read were kept (page by page reads keep the last ones of each type).
  bool get isTruncated => points.length < total;

  /// The types asked for that returned no data.
  List<HealthDataType> get typesWithoutData => [
    for (final type in types)
      if ((counts[type] ?? 0) == 0) type,
  ];

  /// The points by type, in the order of [types] (then any other type), each in [order].
  late final List<TypeGroup> groups = _group();

  /// This result with its points shown in [order].
  QueryResult sortedBy(SortOrder order) => _copy(order: order);

  /// This result with only the [unique] points that `removeDuplicates` kept of [points].
  QueryResult withoutDuplicates(List<HealthDataPoint> unique) {
    final before = _countByType(points);
    final after = _countByType(unique);
    return _copy(
      points: unique,
      counts: {
        for (final MapEntry(key: type, value: count) in counts.entries)
          type: count - ((before[type] ?? 0) - (after[type] ?? 0)),
      },
      removedDuplicates: points.length - unique.length,
    );
  }

  /// This result without [point], for example after it was deleted with `deleteByUUID`.
  QueryResult without(HealthDataPoint point) {
    var index = points.indexWhere((candidate) => identical(candidate, point));
    if (index < 0) index = points.indexOf(point);
    if (index < 0) return this;
    return _copy(
      points: [...points.take(index), ...points.skip(index + 1)],
      counts: {...counts, point.type: (counts[point.type] ?? 1) - 1},
    );
  }

  /// This result with the points of the later read [next] added, as when reads add to the result. The
  /// summary then describes [next], with the counts and pages of both.
  QueryResult followedBy(QueryResult next) {
    final pagesRead = (pages ?? 0) + (next.pages ?? 0);
    return QueryResult(
      types: [...types, ...next.types.where((type) => !types.contains(type))],
      points: [...points, ...next.points],
      counts: {
        ...counts,
        for (final MapEntry(key: type, value: count) in next.counts.entries) type: (counts[type] ?? 0) + count,
      },
      mode: next.mode,
      elapsed: next.elapsed,
      limit: next.limit,
      pages: pages == null && next.pages == null ? null : pagesRead,
      readPermissionDenied: {...readPermissionDenied, ...next.readPermissionDenied},
      cancelled: next.cancelled,
      error: next.error,
      stackTrace: next.stackTrace,
      reads: reads + next.reads,
    );
  }

  List<TypeGroup> _group() {
    final byType = <HealthDataType, List<HealthDataPoint>>{};
    for (final point in points) {
      byType.putIfAbsent(point.type, () => []).add(point);
    }
    // A type the request did not name (none today) still shows, after the others.
    final others = inDisplayOrder(byType.keys.where((type) => !types.contains(type)));
    return [
      for (final type in [...types, ...others])
        if (byType[type] case final kept?)
          TypeGroup(
            type: type,
            points: List.unmodifiable(_sorted(kept, order)),
            count: (counts[type] ?? 0) < kept.length ? kept.length : counts[type]!,
            readPermissionDenied: readPermissionDenied.contains(type),
          ),
    ];
  }

  QueryResult _copy({
    List<HealthDataPoint>? points,
    Map<HealthDataType, int>? counts,
    SortOrder? order,
    int? removedDuplicates,
  }) => QueryResult(
    types: types,
    points: points ?? this.points,
    counts: counts ?? this.counts,
    mode: mode,
    elapsed: elapsed,
    limit: limit,
    pages: pages,
    readPermissionDenied: readPermissionDenied,
    cancelled: cancelled,
    error: error,
    stackTrace: stackTrace,
    order: order ?? this.order,
    removedDuplicates: removedDuplicates ?? this.removedDuplicates,
    reads: reads,
  );

  /// The number of [points] of each type.
  static Map<HealthDataType, int> _countByType(List<HealthDataPoint> points) {
    final counts = <HealthDataType, int>{};
    for (final point in points) {
      counts[point.type] = (counts[point.type] ?? 0) + 1;
    }
    return counts;
  }

  /// [points] in [order]: by start time, then end time; points that tie keep the order they were read in
  /// (`List.sort` alone is not stable).
  static List<HealthDataPoint> _sorted(List<HealthDataPoint> points, SortOrder order) {
    if (order == SortOrder.asReturned) return points;
    final direction = order == SortOrder.newestFirst ? -1 : 1;
    final indexed = points.indexed.toList()
      ..sort((a, b) {
        var byTime = a.$2.dateFrom.compareTo(b.$2.dateFrom);
        if (byTime == 0) byTime = a.$2.dateTo.compareTo(b.$2.dateTo);
        return byTime != 0 ? direction * byTime : a.$1.compareTo(b.$1);
      });
    return [for (final (_, point) in indexed) point];
  }
}
