/// The local copy of Health Connect records that Read > Changes keeps in sync with `Health.getChanges`,
/// as an app that mirrors health data in its own database would.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// What a page of changes did to one record of the local copy.
enum ChangeOutcome {
  /// A record the copy did not have was added.
  inserted('Inserted'),

  /// A record the copy had was replaced by a different version.
  updated('Updated'),

  /// A record the copy had came again unchanged.
  unchanged('Unchanged'),

  /// A record the copy had was deleted.
  removed('Removed'),

  /// A record the copy never had was deleted, for example one written before the token was made.
  unknownDelete('Deleted');

  const ChangeOutcome(this.label);

  /// The outcome's name, as the list of changes shows it.
  final String label;
}

/// What happened to one record in a page of changes, for the list of recent changes.
@immutable
class ChangeEntry {
  /// Creates the entry of the record [recordId].
  const ChangeEntry({required this.recordId, required this.outcome, required this.points, required this.at});

  /// The Health Connect id of the record: the `uuid` of its data points, the `recordId` of its deletion.
  final String recordId;

  /// What happened to the record.
  final ChangeOutcome outcome;

  /// The record's data points: after an upsert its new ones, after a deletion the ones the copy had
  /// (none for a record the copy never had). A heart rate record has one per sample, a blood pressure
  /// record one systolic and one diastolic value.
  final List<HealthDataPoint> points;

  /// When the change was received.
  final DateTime at;

  /// The record's data type, unknown for the deletion of a record the copy never had (Health Connect
  /// reports only the id of a deleted record).
  HealthDataType? get type => points.firstOrNull?.type;
}

/// The result of applying one page of changes ([SyncedRecords.apply]).
@immutable
class AppliedChanges {
  /// Creates the result of a page with [upserts] and [deletes], of which [skipped] could not be applied.
  const AppliedChanges({required this.upserts, required this.deletes, required this.skipped, required this.entries});

  /// The upsert changes in the page: one per data point, so a record can bring several.
  final int upserts;

  /// The delete changes in the page: one per record.
  final int deletes;

  /// Changes without a data point or a record id, which cannot be applied.
  final int skipped;

  /// One entry per record the page touched, in the order the records first appeared.
  final List<ChangeEntry> entries;

  /// How many records had [outcome].
  int count(ChangeOutcome outcome) => entries.where((entry) => entry.outcome == outcome).length;
}

/// The records synced so far, by Health Connect record id, each with its data points.
///
/// Health Connect reports changes per record, and the plugin turns an upserted record into its data
/// points: one for most types, one per sample for heart rate and the other series types, two for blood
/// pressure. All of them carry the record's id as their `uuid`, which is also the `recordId` of the
/// record's deletion. So the copy is keyed by record id, and an upsert replaces all points of its record.
class SyncedRecords {
  final Map<String, List<HealthDataPoint>> _byId = {};

  /// How many records the copy holds.
  int get recordCount => _byId.length;

  /// How many data points those records have.
  int get pointCount => _byId.values.fold(0, (sum, points) => sum + points.length);

  /// The data points of the record [recordId], or null if the copy does not have it.
  List<HealthDataPoint>? operator [](String recordId) => _byId[recordId];

  /// Applies one page of [changes] (`HealthChangesResponse.changes`), received at [at] (now by default),
  /// and reports what they did.
  AppliedChanges apply(List<HealthChange> changes, {DateTime? at}) {
    final received = at ?? DateTime.now();
    var upserts = 0;
    var deletes = 0;
    var skipped = 0;
    // Each touched record's points from this page, or null once deleted, in the order records appear.
    // Within a record, points are keyed by type and start: unique per sample and per blood pressure value,
    // so a record that comes twice in one page is not doubled.
    final touched = <String, Map<(HealthDataType, DateTime), HealthDataPoint>?>{};
    for (final change in changes) {
      if (change.type == HealthChangeType.delete) {
        deletes++;
        final id = change.recordId;
        if (id == null || id.isEmpty) {
          skipped++;
        } else {
          touched[id] = null;
        }
        continue;
      }
      upserts++;
      final point = change.dataPoint;
      // A record type the plugin cannot convert comes without a data point.
      if (point == null || point.uuid.isEmpty) {
        skipped++;
        continue;
      }
      (touched[point.uuid] ??= {})[(point.type, point.dateFrom)] = point;
    }

    final entries = <ChangeEntry>[];
    for (final MapEntry(key: id, value: fresh) in touched.entries) {
      final old = _byId[id];
      if (fresh == null) {
        _byId.remove(id);
        final outcome = old == null ? ChangeOutcome.unknownDelete : ChangeOutcome.removed;
        entries.add(ChangeEntry(recordId: id, outcome: outcome, points: old ?? const [], at: received));
        continue;
      }
      final points = List<HealthDataPoint>.unmodifiable(fresh.values);
      _byId[id] = points;
      final outcome = old == null
          ? ChangeOutcome.inserted
          : listEquals(old, points)
          ? ChangeOutcome.unchanged
          : ChangeOutcome.updated;
      entries.add(ChangeEntry(recordId: id, outcome: outcome, points: points, at: received));
    }
    return AppliedChanges(upserts: upserts, deletes: deletes, skipped: skipped, entries: List.unmodifiable(entries));
  }

  /// Forgets every record, as before a full resync.
  void clear() => _byId.clear();
}
