import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/time/time_range.dart';
import 'package:health_example/features/read/query/query_options.dart';
import 'package:health_example/features/read/query/query_result.dart';

import '../support/read_health.dart';

const _steps = HealthDataType.STEPS;
const _heartRate = HealthDataType.HEART_RATE;
const _weight = HealthDataType.WEIGHT;

void main() {
  group('QueryOptions', () {
    final range = TimeRange.preset(TimeRangePreset.last24Hours);

    test('start with steps and heart rate, or the first available type', () {
      expect(QueryOptions.initial([_weight, _steps, _heartRate]).types, {_steps, _heartRate});
      expect(QueryOptions.initial([_weight]).types, {_weight});
      expect(QueryOptions.initial(const []).types, isEmpty);
    });

    test('read the types in the order the chips show them: by category, then name', () {
      final options = QueryOptions(types: const {_heartRate, _weight, _steps}, range: range);
      expect(options.orderedTypes, [_steps, _weight, _heartRate]);
    });

    test('pass a limit only to reads all at once, and 0 as no limit', () {
      final options = QueryOptions(types: const {_steps}, range: range, limit: 10);
      expect(options.effectiveLimit, 10);
      expect(options.copyWith(limit: 0).effectiveLimit, isNull);
      expect(options.copyWith(mode: QueryMode.pages).effectiveLimit, isNull);
    });

    test('ask for imperial units only of the types Health Connect converts', () {
      final options = QueryOptions(types: const {_steps}, range: range);
      expect(options.preferredUnits, isNull);
      expect(options.copyWith(imperialUnits: true).preferredUnits, {
        HealthDataType.WEIGHT: HealthDataUnit.POUND,
        HealthDataType.HEIGHT: HealthDataUnit.INCH,
        HealthDataType.BODY_TEMPERATURE: HealthDataUnit.DEGREE_FAHRENHEIT,
      });
    });
  });

  group('QueryResult', () {
    QueryResult read(List<HealthDataPoint> points, {List<HealthDataType> types = const [_steps, _heartRate]}) =>
        QueryResult.fromList(types, points, elapsed: const Duration(milliseconds: 40));

    test('counts the points of each type, including types without data', () {
      final result = read([pointAt(0), pointAt(10, uuid: 'record-2')]);

      expect(result.total, 2);
      expect(result.counts, {_steps: 2, _heartRate: 0});
      expect(result.typesWithoutData, [_heartRate]);
      expect(result.isTruncated, isFalse);
      expect(result.groups.map((group) => (group.type, group.count)), [(_steps, 2)]);
    });

    test('groups the points by type in the order the types were read', () {
      final result = read([pointAt(0, type: _heartRate), pointAt(5), pointAt(9, type: _heartRate)]);

      expect(result.groups.map((group) => group.type), [_steps, _heartRate]);
      expect(result.groups.last.points.map((point) => point.dateFrom.minute), [0, 9]);
    });

    test('sorts newest or oldest first, keeping the read order of points that tie', () {
      final tieA = pointAt(5, uuid: 'a');
      final tieB = pointAt(5, uuid: 'b');
      final result = read([pointAt(10), tieA, pointAt(0), tieB]);

      List<String> order(SortOrder order) =>
          result.sortedBy(order).groups.single.points.map((p) => '${p.dateFrom.minute}${p.uuid}').toList();
      expect(order(SortOrder.newestFirst), ['10record-1', '5a', '5b', '0record-1']);
      expect(order(SortOrder.oldestFirst), ['0record-1', '5a', '5b', '10record-1']);
      expect(order(SortOrder.asReturned), ['10record-1', '5a', '0record-1', '5b']);
    });

    test('keeps what removeDuplicates kept, and says how many went', () {
      final health = ReadHealth();
      final result = read([pointAt(0), pointAt(0), pointAt(0, type: _heartRate), pointAt(0, type: _heartRate)]);

      final deduplicated = result.withoutDuplicates(health.removeDuplicates(result.points));

      expect(deduplicated.removedDuplicates, 2);
      expect(deduplicated.counts, {_steps: 1, _heartRate: 1});
      expect(deduplicated.total, 2);
      expect(read([pointAt(0)]).withoutDuplicates([pointAt(0)]).removedDuplicates, 0);
    });

    test('drops a deleted point and its count', () {
      final deleted = pointAt(5, uuid: 'gone');
      final result = read([pointAt(0), deleted]).without(deleted);

      expect(result.points.map((point) => point.uuid), ['record-1']);
      expect(result.counts[_steps], 1);
    });

    test('adds a later read to the result, keeping the chosen order', () {
      final first = QueryResult(
        types: const [_steps],
        points: [pointAt(0)],
        counts: const {_steps: 1},
        mode: QueryMode.pages,
        elapsed: Duration.zero,
        pages: 2,
      ).sortedBy(SortOrder.newestFirst);
      final second = QueryResult(
        types: const [_steps, _weight],
        points: [pointAt(30)],
        counts: const {_steps: 1, _weight: 0},
        mode: QueryMode.pages,
        elapsed: const Duration(milliseconds: 7),
        pages: 3,
        readPermissionDenied: const {_weight},
      );

      final both = first.followedBy(second);

      expect(both.types, [_steps, _weight]);
      expect(both.counts, {_steps: 2, _weight: 0});
      expect(both.pages, 5);
      expect(both.reads, 2);
      expect(both.elapsed, const Duration(milliseconds: 7), reason: 'the summary describes the last read');
      expect(both.readPermissionDenied, {_weight});
      expect(both.order, SortOrder.newestFirst);
      expect(both.groups.single.points.map((point) => point.dateFrom.minute), [30, 0]);
    });

    test('a group of a truncated read knows it shows only some of its points', () {
      final result = QueryResult(
        types: const [_steps],
        points: [pointAt(0)],
        counts: const {_steps: 5000},
        mode: QueryMode.pages,
        elapsed: Duration.zero,
      );

      expect(result.isTruncated, isTrue);
      expect(result.groups.single.isTruncated, isTrue);
      expect(result.groups.single.count, 5000);
    });
  });
}
