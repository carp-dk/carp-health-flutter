import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/features/read/query/page_accumulator.dart';
import 'package:health_example/features/read/query/query_options.dart';

import '../support/read_health.dart';

const _steps = HealthDataType.STEPS;
const _weight = HealthDataType.WEIGHT;

void main() {
  test('counts every point but keeps only the last ones of each type', () {
    final accumulator = PageAccumulator(const [_steps], keepPerType: 3);

    accumulator.add(page(_steps, [for (var i = 0; i < 4; i++) pointAt(i)]));
    accumulator.add(page(_steps, [pointAt(4)], last: true));
    final result = accumulator.build(elapsed: const Duration(milliseconds: 12));

    expect(accumulator.pages, 2);
    expect(accumulator.points, 5);
    expect(result.points.map((point) => point.dateFrom.minute), [2, 3, 4]);
    expect(result.counts, {_steps: 5});
    expect(result.isTruncated, isTrue);
    expect(result.mode, QueryMode.pages);
    expect(result.pages, 2);
  });

  test('follows the types done, determinately only for reads of several types', () {
    final accumulator = PageAccumulator(const [_steps, _weight]);
    expect(accumulator.progress.fraction, 0);
    expect(accumulator.progress.currentType, isNull);

    accumulator.add(page(_steps, [pointAt(0)], last: true));
    expect(accumulator.progress.typesDone, 1);
    expect(accumulator.progress.fraction, 0.5);
    expect(accumulator.progress.currentType, _steps);

    final single = PageAccumulator(const [_steps])..add(page(_steps, [pointAt(0)]));
    expect(single.progress.fraction, isNull, reason: 'the pages of one type cannot be known ahead');
  });

  test('collects the types read without the read permission (Android)', () {
    final accumulator = PageAccumulator(const [_steps, _weight])
      ..add(page(_steps, [pointAt(0)], last: true))
      ..add(page(_weight, const [], last: true, readPermissionDenied: true));

    final result = accumulator.build(elapsed: Duration.zero);

    expect(result.readPermissionDenied, {_weight});
    expect(result.counts, {_steps: 1, _weight: 0});
    expect(result.typesWithoutData, [_weight]);
  });

  test('builds a cancelled or failed read from the pages before', () {
    final accumulator = PageAccumulator(const [_steps])..add(page(_steps, [pointAt(0)]));
    final error = StateError('boom');

    final cancelled = accumulator.build(elapsed: Duration.zero, cancelled: true);
    final failed = accumulator.build(elapsed: Duration.zero, error: error);

    expect(cancelled.cancelled, isTrue);
    expect(cancelled.total, 1);
    expect(failed.error, same(error));
    expect(failed.points, hasLength(1));
  });
}
