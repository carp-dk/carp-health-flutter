import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/features/read/changes/changes_summary.dart';
import 'package:health_example/features/read/changes/synced_records.dart';

import '../support/read_health.dart';

void main() {
  late SyncedRecords records;

  setUp(() => records = SyncedRecords());

  List<(String, ChangeOutcome)> outcomes(AppliedChanges applied) => [
    for (final entry in applied.entries) (entry.recordId, entry.outcome),
  ];

  test('inserts new records, keyed by their Health Connect id', () {
    final applied = records.apply([upsertChange('a'), upsertChange('b', value: 7)]);

    expect(outcomes(applied), [('a', ChangeOutcome.inserted), ('b', ChangeOutcome.inserted)]);
    expect(applied.upserts, 2);
    expect(records.recordCount, 2);
    expect(records['b']!.single.value, NumericHealthValue(numericValue: 7));
  });

  test('tells an updated record from one that came again unchanged', () {
    records.apply([upsertChange('a'), upsertChange('b')]);

    final applied = records.apply([upsertChange('a', value: 250), upsertChange('b')]);

    expect(outcomes(applied), [('a', ChangeOutcome.updated), ('b', ChangeOutcome.unchanged)]);
    expect(applied.count(ChangeOutcome.updated), 1);
  });

  test('removes deleted records, and tells deletions of records it never had', () {
    records.apply([upsertChange('a')]);

    final applied = records.apply([deleteChange('a'), deleteChange('elsewhere')]);

    expect(outcomes(applied), [('a', ChangeOutcome.removed), ('elsewhere', ChangeOutcome.unknownDelete)]);
    expect(applied.deletes, 2);
    expect(applied.entries.first.points, hasLength(1), reason: 'the entry keeps what was deleted');
    expect(applied.entries.first.type, HealthDataType.STEPS);
    expect(applied.entries.last.type, isNull, reason: 'Health Connect reports only the id');
    expect(records.recordCount, 0);
  });

  test('keeps the samples of a series record together, without doubling a record sent twice', () {
    final applied = records.apply([
      upsertChange('hr', type: HealthDataType.HEART_RATE, value: 70),
      upsertChange('hr', type: HealthDataType.HEART_RATE, value: 72, minutes: 1),
      upsertChange('hr', type: HealthDataType.HEART_RATE, value: 72, minutes: 1),
    ]);

    expect(outcomes(applied), [('hr', ChangeOutcome.inserted)]);
    expect(records.recordCount, 1);
    expect(records.pointCount, 2);
    expect(applied.upserts, 3);
  });

  test('skips changes it cannot apply', () {
    final noPoint = HealthChange.fromMethodChannel({'type': 'upsert', 'dataTypeKey': 'NOT_A_TYPE', 'dataPoint': {}});
    final noId = HealthChange.fromMethodChannel({'type': 'delete'});

    final applied = records.apply([noPoint, noId]);

    expect(applied.skipped, 2);
    expect(applied.entries, isEmpty);
  });

  test('clear forgets every record', () {
    records
      ..apply([upsertChange('a')])
      ..clear();

    expect(records.recordCount, 0);
    expect(records['a'], isNull);
  });

  test('a summary adds up the pages of a sync', () {
    final first = records.apply([upsertChange('a'), upsertChange('b')]);
    final second = records.apply([upsertChange('a', value: 9), deleteChange('b'), deleteChange('c')]);

    final summary = const ChangesSummary.start(0)
        .add(first, records: 2, hasMore: true, tokenExpired: false, elapsed: Duration.zero)
        .add(second, records: 1, hasMore: false, tokenExpired: false, elapsed: const Duration(milliseconds: 9))
        .finish(const Duration(milliseconds: 10));

    expect(summary.calls, 2);
    expect(summary.changes, 5);
    expect((summary.inserted, summary.updated, summary.removed, summary.unknownDeletes), (2, 1, 1, 1));
    expect((summary.recordsBefore, summary.recordsAfter), (0, 1));
    expect(summary.hasMore, isFalse);
    expect(summary.elapsed, const Duration(milliseconds: 10));
  });
}
