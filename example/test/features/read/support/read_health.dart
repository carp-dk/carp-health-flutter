/// Test support for the Read feature: a [Health] whose reads and changes API answer from scripts, the
/// data points and changes it returns, and the app around the Read page.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/design/design.dart';

import '../../../shared/support/sample_points.dart';
import '../../../shared/support/shared_test_app.dart';

/// The arguments of one read, as the plugin received them.
typedef ReadCall = ({
  List<HealthDataType> types,
  DateTime start,
  DateTime end,
  int? limit,
  int? pageSize,
  Map<HealthDataType, HealthDataUnit>? preferredUnits,
  List<RecordingMethod> filtered,
});

/// A [LookupHealth] (which also answers `getHealthDataByUUID`) whose reads and changes API answer from
/// fields, and which records the calls.
class ReadHealth extends LookupHealth {
  /// What `getHealthDataFromTypes` returns.
  List<HealthDataPoint> points = [];

  /// Thrown by `getHealthDataFromTypes` when set.
  Object? readError;

  /// The `getHealthDataFromTypes` and `getHealthDataPages` calls made.
  final List<ReadCall> reads = [];

  /// The stream of the latest `getHealthDataPages` call: tests add its pages, errors and end.
  StreamController<HealthDataPage>? pages;

  /// Whether the latest stream of pages was cancelled.
  bool pagesCancelled = false;

  /// When set, cancelling the stream of pages waits for it, as the plugin's `cancel()` waits for the
  /// platform call in flight; tests complete it to let the cancel finish.
  Completer<void>? cancelHold;

  /// Thrown by the cancel of the stream of pages when set, as a stream other than the plugin's might.
  Object? cancelError;

  /// What `getChangesToken` returns, unless [tokenError] is set.
  String? token = 'token-1';

  /// Thrown by `getChangesToken` when set.
  Object? tokenError;

  /// The types of the `getChangesToken` calls made.
  final List<List<HealthDataType>> tokenRequests = [];

  /// What the next `getChanges` calls answer, in order: a [HealthChangesResponse], or anything else to
  /// throw. When none is left, a call answers no changes and no more.
  final List<Object> changePages = [];

  /// The token and `includeSelf` of the `getChanges` calls made.
  final List<(String, bool)> changeRequests = [];

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? limit,
  }) async {
    reads.add((
      types: types,
      start: startTime,
      end: endTime,
      limit: limit,
      pageSize: null,
      preferredUnits: preferredUnits,
      filtered: recordingMethodsToFilter,
    ));
    await hold?.future;
    if (readError case final error?) throw error;
    return [...points];
  }

  @override
  Stream<HealthDataPage> getHealthDataPages({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? pageSize,
  }) {
    reads.add((
      types: types,
      start: startTime,
      end: endTime,
      limit: null,
      pageSize: pageSize,
      preferredUnits: preferredUnits,
      filtered: recordingMethodsToFilter,
    ));
    pagesCancelled = false;
    final controller = pages = StreamController<HealthDataPage>(
      // An async callback, so the future that `cancel()` returns completes in the test's zone. A plain
      // callback makes `cancel()` return a future of the root zone, which fake time in widget tests never
      // completes.
      onCancel: () async {
        pagesCancelled = true;
        await cancelHold?.future;
        if (cancelError case final error?) throw error;
      },
    );
    return controller.stream;
  }

  @override
  Future<String?> getChangesToken({required List<HealthDataType> types}) async {
    tokenRequests.add(types);
    if (tokenError case final error?) throw error;
    return token;
  }

  @override
  Future<HealthChangesResponse?> getChanges({required String changesToken, bool includeSelf = false}) async {
    changeRequests.add((changesToken, includeSelf));
    await hold?.future;
    if (changePages.isEmpty) {
      return HealthChangesResponse(
        changes: const [],
        nextChangesToken: '$changesToken+',
        hasMore: false,
        changesTokenExpired: false,
      );
    }
    final next = changePages.removeAt(0);
    if (next is HealthChangesResponse) return next;
    throw next;
  }
}

/// A numeric [type] point (steps by default) of [value] with [uuid], from [minutes] after [sampleStart]
/// for ten minutes.
HealthDataPoint pointAt(
  int minutes, {
  HealthDataType type = HealthDataType.STEPS,
  String uuid = 'record-1',
  num value = 100,
}) {
  final start = sampleStart.add(Duration(minutes: minutes));
  return HealthDataPoint(
    uuid: uuid,
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: dataTypeToUnit[type]!,
    dateFrom: start,
    dateTo: start.add(const Duration(minutes: 10)),
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device-42',
    sourceId: '',
    sourceName: 'com.example.watch',
    recordingMethod: RecordingMethod.automatic,
  );
}

/// A page of [points] of [type] from `getHealthDataPages`.
HealthDataPage page(
  HealthDataType type,
  List<HealthDataPoint> points, {
  bool last = false,
  bool readPermissionDenied = false,
}) => HealthDataPage(type: type, points: points, isLastPageForType: last, readPermissionDenied: readPermissionDenied);

/// The upsert of the [type] record [id] holding [value], from [minutes] after [sampleStart], as
/// `getChanges` reports it (the plugin parses it from this channel map).
HealthChange upsertChange(String id, {HealthDataType type = HealthDataType.STEPS, num value = 100, int minutes = 0}) {
  final from = sampleStart.add(Duration(minutes: minutes));
  return HealthChange.fromMethodChannel({
    'type': 'upsert',
    'dataTypeKey': type.name,
    'dataPoint': {
      'uuid': id,
      'value': value,
      'date_from': from.millisecondsSinceEpoch,
      'date_to': from.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      'source_id': '',
      'source_name': 'com.example.watch',
      'recording_method': 1,
    },
  });
}

/// The deletion of the record [id], as `getChanges` reports it: only the id.
HealthChange deleteChange(String id) => HealthChange.fromMethodChannel({'type': 'delete', 'recordId': id});

/// A page of [changes] from `getChanges`, with [next] as the token to use next.
HealthChangesResponse changesPage(
  List<HealthChange> changes, {
  required String next,
  bool hasMore = false,
  bool expired = false,
}) => HealthChangesResponse(changes: changes, nextChangesToken: next, hasMore: hasMore, changesTokenExpired: expired);

/// [page] in the app as the shell shows it: inside [services] and the app's navigation (switched by
/// [destination], when given), with the light expressive theme.
Widget readTestApp(AppServices services, Widget page, {ValueNotifier<AppDestination>? destination}) => AppScope(
  services: services,
  child: AppNavigation(
    notifier: destination ?? ValueNotifier(AppDestination.read),
    child: MaterialApp(theme: ExpressiveTheme.light(), home: page),
  ),
);
