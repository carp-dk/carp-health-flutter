/// What a query reads and how: the data types, the time range and the arguments of
/// `Health.getHealthDataFromTypes` and `Health.getHealthDataPages`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:health/health.dart';
import 'package:health_example/core/time/time_range.dart';

import '../type_order.dart';

/// How a query reads: in one call, or page by page.
enum QueryMode {
  /// `getHealthDataFromTypes`: every data point in one list, or only the newest few of each type.
  allAtOnce('All at once', Icons.download_outlined, 'getHealthDataFromTypes'),

  /// `getHealthDataPages`: a lazy stream of pages; memory stays bounded and the read can be cancelled.
  pages('Page by page', Icons.view_agenda_outlined, 'getHealthDataPages');

  const QueryMode(this.label, this.icon, this.method);

  /// The mode's name in the form.
  final String label;

  /// The icon of the mode's segment.
  final IconData icon;

  /// The plugin method the mode calls.
  final String method;
}

/// The options of a query. Immutable: the form makes changed copies with [copyWith].
@immutable
class QueryOptions {
  /// Creates query options.
  const QueryOptions({
    required this.types,
    required this.range,
    this.mode = QueryMode.allAtOnce,
    this.limit = 0,
    this.recordingMethodsToFilter = const {},
    this.imperialUnits = false,
    this.appendResults = false,
  });

  /// The options a query starts with: steps and heart rate (those of them in [available]) over the last
  /// 24 hours, read all at once.
  factory QueryOptions.initial(List<HealthDataType> available) => QueryOptions(
    types: initialTypes(const {HealthDataType.STEPS, HealthDataType.HEART_RATE}, available),
    range: TimeRange.preset(TimeRangePreset.last24Hours),
  );

  /// The limits the form offers; 0 means no limit.
  static const List<int> limits = [0, 1, 10, 100];

  /// The units of the imperial units option, as `preferredUnits`. Health Connect converts these types to
  /// these units (other `preferredUnits` throw `HealthErrorCode.invalidArgument` on Android); HealthKit
  /// converts to any unit of the same kind. Types not in the map come in their default unit.
  static const Map<HealthDataType, HealthDataUnit> imperialUnitsByType = {
    HealthDataType.WEIGHT: HealthDataUnit.POUND,
    HealthDataType.HEIGHT: HealthDataUnit.INCH,
    HealthDataType.BODY_TEMPERATURE: HealthDataUnit.DEGREE_FAHRENHEIT,
  };

  /// The data types to read (`types`).
  final Set<HealthDataType> types;

  /// The time range to read (`startTime` and `endTime`).
  final TimeRange range;

  /// Whether to read all at once or page by page.
  final QueryMode mode;

  /// At most this many of the newest points of each type (`limit` of `getHealthDataFromTypes`); 0 for all.
  final int limit;

  /// The recording methods to leave out (`recordingMethodsToFilter`).
  final Set<RecordingMethod> recordingMethodsToFilter;

  /// Whether to ask for pounds, inches and degrees Fahrenheit ([imperialUnitsByType] as `preferredUnits`).
  final bool imperialUnits;

  /// Whether a read adds its points to the current result instead of replacing it, as an app that keeps
  /// the points of several reads together does; `removeDuplicates` then has duplicates to remove.
  final bool appendResults;

  /// [types] in the order the form shows them, which is the order the plugin reads them in.
  List<HealthDataType> get orderedTypes => inDisplayOrder(types);

  /// The `limit` argument: null (no limit) for 0 and for page by page reads, which have no limit.
  int? get effectiveLimit => mode == QueryMode.allAtOnce && limit > 0 ? limit : null;

  /// The `preferredUnits` argument: [imperialUnitsByType] or null for the default units (`dataTypeToUnit`).
  Map<HealthDataType, HealthDataUnit>? get preferredUnits => imperialUnits ? imperialUnitsByType : null;

  /// A copy with the given options changed.
  QueryOptions copyWith({
    Set<HealthDataType>? types,
    TimeRange? range,
    QueryMode? mode,
    int? limit,
    Set<RecordingMethod>? recordingMethodsToFilter,
    bool? imperialUnits,
    bool? appendResults,
  }) => QueryOptions(
    types: types ?? this.types,
    range: range ?? this.range,
    mode: mode ?? this.mode,
    limit: limit ?? this.limit,
    recordingMethodsToFilter: recordingMethodsToFilter ?? this.recordingMethodsToFilter,
    imperialUnits: imperialUnits ?? this.imperialUnits,
    appendResults: appendResults ?? this.appendResults,
  );

  @override
  String toString() => 'QueryOptions(${types.map((type) => type.name).join(', ')}, $range, ${mode.name})';
}
