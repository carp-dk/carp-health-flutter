import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/features/read/query/query_controller.dart';
import 'package:health_example/features/read/query/query_options.dart';
import 'package:health_example/features/read/query/query_result.dart';

import '../support/read_health.dart';

const _steps = HealthDataType.STEPS;
const _heartRate = HealthDataType.HEART_RATE;

void main() {
  late ReadHealth health;
  late PluginSettings settings;
  late QueryController controller;

  setUp(() {
    health = ReadHealth();
    settings = PluginSettings(health);
    controller = QueryController(health: health, settings: settings, available: const [_heartRate, _steps]);
  });
  tearDown(() {
    controller.dispose();
    settings.dispose();
  });

  QueryResult resultOf(QueryController controller) => (controller.result as AsyncData<QueryResult>).value;

  group('all at once', () {
    test('reads with getHealthDataFromTypes and the chosen arguments', () async {
      health.points = [pointAt(0), pointAt(3, type: _heartRate)];
      controller.options = controller.options.copyWith(
        limit: 10,
        imperialUnits: true,
        recordingMethodsToFilter: {RecordingMethod.manual},
      );

      final reading = controller.read();
      expect(controller.isReading, isTrue);
      expect(controller.canCancel, isFalse, reason: 'a read all at once cannot be cancelled');
      await reading;

      final call = health.reads.single;
      expect(call.types, [_steps, _heartRate]);
      expect(call.limit, 10);
      expect(call.preferredUnits, QueryOptions.imperialUnitsByType);
      expect(call.filtered, [RecordingMethod.manual]);
      expect(call.end.difference(call.start), const Duration(hours: 24));
      expect(resultOf(controller).counts, {_steps: 1, _heartRate: 1});
      expect(resultOf(controller).limit, 10);
      expect(controller.isReading, isFalse);
    });

    test('turns an error into an AsyncError instead of throwing', () async {
      health.readError = HealthPlatformException(
        _steps,
        PlatformException(code: 'RATE_LIMIT_EXCEEDED', message: 'Quota used up'),
      );

      await controller.read();

      expect(controller.result.errorOrNull, isA<HealthPlatformException>());
      expect(controller.canRead, isTrue);
    });

    test('adds reads up when asked, so that removeDuplicates finds the points read twice', () async {
      health.points = [pointAt(0), pointAt(5)];
      controller.options = controller.options.copyWith(appendResults: true);

      await controller.read();
      await controller.read();
      expect(resultOf(controller).total, 4);
      expect(resultOf(controller).reads, 2);

      controller.removeDuplicates();
      expect(resultOf(controller).total, 2);
      expect(resultOf(controller).removedDuplicates, 2);
    });

    test('sorts, drops deleted points and clears the result', () async {
      final later = pointAt(30, uuid: 'later');
      health.points = [pointAt(0), later];
      await controller.read();

      controller.sortBy(SortOrder.newestFirst);
      expect(resultOf(controller).groups.single.points.first, same(later));

      controller.removePoint(later);
      expect(resultOf(controller).total, 1);

      controller.clear();
      expect(controller.result, isA<AsyncIdle<QueryResult>>());
    });

    test('does nothing without types', () async {
      controller.options = controller.options.copyWith(types: const {});

      await controller.read();

      expect(health.reads, isEmpty);
      expect(controller.result, isA<AsyncIdle<QueryResult>>());
    });
  });

  group('page by page', () {
    setUp(() {
      controller.options = controller.options.copyWith(mode: QueryMode.pages, limit: 10);
      settings.pageSize = 5000;
    });

    test('streams getHealthDataPages with the page size, following the pages as they come', () async {
      final reading = controller.read();
      await pumpEventQueue();
      expect(health.reads.single.pageSize, 5000);
      expect(health.reads.single.limit, isNull, reason: 'page by page reads have no limit');

      health.pages!.add(page(_steps, [pointAt(0), pointAt(1)], last: true));
      await pumpEventQueue();
      expect(controller.progress!.pages, 1);
      expect(controller.progress!.points, 2);
      expect(controller.progress!.typesDone, 1);

      health.pages!.add(page(_heartRate, const [], last: true, readPermissionDenied: true));
      await health.pages!.close();
      await reading;

      final result = resultOf(controller);
      expect(result.pages, 2);
      expect(result.counts, {_steps: 2, _heartRate: 0});
      expect(result.readPermissionDenied, {_heartRate});
      expect(controller.progress, isNull);
    });

    test('Cancel cancels the subscription and keeps the pages read before', () async {
      final reading = controller.read();
      await pumpEventQueue();
      health.pages!.add(page(_steps, [pointAt(0)]));
      await pumpEventQueue();
      expect(controller.canCancel, isTrue);

      await controller.cancel();
      await reading;

      expect(health.pagesCancelled, isTrue);
      final result = resultOf(controller);
      expect(result.cancelled, isTrue);
      expect(result.total, 1);
      expect(controller.isReading, isFalse);
    });

    test('stays cancelling until the platform call in flight has returned', () async {
      health.cancelHold = Completer<void>();
      final reading = controller.read();
      await pumpEventQueue();

      final cancelling = controller.cancel();
      await pumpEventQueue();
      expect(controller.isCancelling, isTrue);
      expect(controller.canCancel, isFalse, reason: 'one cancel at a time');
      expect(controller.isReading, isTrue);

      health.cancelHold!.complete();
      await cancelling;
      await reading;
      expect(controller.isCancelling, isFalse);
      expect(resultOf(controller).cancelled, isTrue);
    });

    test('a cancel that fails still ends the read, without throwing', () async {
      health.cancelError = StateError('cancel failed');
      final reading = controller.read();
      await pumpEventQueue();
      health.pages!.add(page(_steps, [pointAt(0)]));
      await pumpEventQueue();

      await controller.cancel();
      await reading;

      expect(resultOf(controller).cancelled, isTrue);
      expect(resultOf(controller).total, 1);
      expect(controller.isReading, isFalse);
    });

    test('an error after some pages ends the read but keeps them', () async {
      final reading = controller.read();
      await pumpEventQueue();
      health.pages!
        ..add(page(_steps, [pointAt(0)]))
        ..addError(StateError('lost'));
      await reading;

      final result = resultOf(controller);
      expect(result.error, isA<StateError>());
      expect(result.total, 1);
    });

    test('an error before the first page fails the read', () async {
      final reading = controller.read();
      await pumpEventQueue();
      health.pages!.addError(RangeError('pageSize'));
      await reading;

      expect(controller.result.errorOrNull, isA<RangeError>());
    });

    test('disposing during a read cancels it and lets read() complete', () async {
      final reading = controller.read();
      await pumpEventQueue();

      controller.dispose();
      await reading;

      expect(health.pagesCancelled, isTrue);
      // tearDown disposes again: make that a fresh controller.
      controller = QueryController(health: health, settings: settings, available: const [_steps]);
    });
  });
}
