/// What one sync with `Health.getChanges` did: the counters Read > Changes shows.
library;

import 'package:flutter/foundation.dart';

import 'synced_records.dart';

/// The counts of one sync: the `getChanges` calls it made (one per page of changes, repeated while
/// `hasMore`), the changes they returned and what applying them did to the [SyncedRecords].
@immutable
class ChangesSummary {
  /// Creates a summary; [ChangesSummary.start] begins one and [add] adds each page.
  const ChangesSummary({
    required this.recordsBefore,
    required this.recordsAfter,
    this.calls = 0,
    this.upserts = 0,
    this.deletes = 0,
    this.skipped = 0,
    this.inserted = 0,
    this.updated = 0,
    this.unchanged = 0,
    this.removed = 0,
    this.unknownDeletes = 0,
    this.hasMore = false,
    this.tokenExpired = false,
    this.elapsed = Duration.zero,
    this.error,
    this.stackTrace,
  });

  /// The summary of a sync that has not called the plugin yet, starting from a copy of [records] records.
  const ChangesSummary.start(int records) : this(recordsBefore: records, recordsAfter: records);

  /// The records in the local copy before the sync.
  final int recordsBefore;

  /// The records in the local copy after the sync (so far).
  final int recordsAfter;

  /// The `getChanges` calls made.
  final int calls;

  /// The upsert changes received: one per data point.
  final int upserts;

  /// The delete changes received: one per record.
  final int deletes;

  /// The changes that could not be applied (no data point or record id).
  final int skipped;

  /// The records added to the copy.
  final int inserted;

  /// The records the copy had that changed.
  final int updated;

  /// The records the copy had that came again unchanged.
  final int unchanged;

  /// The records deleted from the copy.
  final int removed;

  /// The deletions of records the copy never had.
  final int unknownDeletes;

  /// Whether Health Connect has more changes than the sync fetched (`HealthChangesResponse.hasMore` of
  /// the last call), because the sync stopped at its call limit.
  final bool hasMore;

  /// Whether the last call reported the token as expired (`HealthChangesResponse.changesTokenExpired`).
  final bool tokenExpired;

  /// How long the sync took.
  final Duration elapsed;

  /// The error that ended the sync after some calls had succeeded; their changes stay applied.
  final Object? error;

  /// Where [error] was thrown.
  final StackTrace? stackTrace;

  /// The changes received in all.
  int get changes => upserts + deletes;

  /// This summary with one more page of changes, [applied] to a copy that now holds [records] records.
  ChangesSummary add(
    AppliedChanges applied, {
    required int records,
    required bool hasMore,
    required bool tokenExpired,
    required Duration elapsed,
  }) => ChangesSummary(
    recordsBefore: recordsBefore,
    recordsAfter: records,
    calls: calls + 1,
    upserts: upserts + applied.upserts,
    deletes: deletes + applied.deletes,
    skipped: skipped + applied.skipped,
    inserted: inserted + applied.count(ChangeOutcome.inserted),
    updated: updated + applied.count(ChangeOutcome.updated),
    unchanged: unchanged + applied.count(ChangeOutcome.unchanged),
    removed: removed + applied.count(ChangeOutcome.removed),
    unknownDeletes: unknownDeletes + applied.count(ChangeOutcome.unknownDelete),
    hasMore: hasMore,
    tokenExpired: tokenExpired,
    elapsed: elapsed,
  );

  /// This summary, ended after [elapsed], by [error] when one was thrown.
  ChangesSummary finish(Duration elapsed, {Object? error, StackTrace? stackTrace}) => ChangesSummary(
    recordsBefore: recordsBefore,
    recordsAfter: recordsAfter,
    calls: calls,
    upserts: upserts,
    deletes: deletes,
    skipped: skipped,
    inserted: inserted,
    updated: updated,
    unchanged: unchanged,
    removed: removed,
    unknownDeletes: unknownDeletes,
    hasMore: hasMore,
    tokenExpired: tokenExpired,
    elapsed: elapsed,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  String toString() =>
      'ChangesSummary($calls calls, +$inserted ~$updated -$removed, records $recordsBefore → $recordsAfter)';
}
