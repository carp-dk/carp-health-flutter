/// A log of what the example wrote in this session, so the data can be looked up again with
/// `getHealthDataByUUID` and removed with `deleteByUUID` or `deleteByClientRecordId`.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// One write: what was written and the ids the plugin returned for it.
class RecentWrite {
  /// Records a write of [type] described by [description], made at [at] (now by default).
  ///
  /// [uuid] is the id a `...UUID` write method returned; an empty one, which those methods return
  /// when nothing was saved, is kept as null. [clientRecordId] is the Health Connect client
  /// record id the write used, if any.
  RecentWrite({required this.type, required this.description, String? uuid, this.clientRecordId, DateTime? at})
    : uuid = (uuid == null || uuid.isEmpty) ? null : uuid,
      at = at ?? DateTime.now();

  /// The data type written.
  final HealthDataType type;

  /// What was written, such as "72 bpm" or "Running, 30 min".
  final String description;

  /// The record's UUID, for `getHealthDataByUUID` and `deleteByUUID`; null if unknown.
  final String? uuid;

  /// The Health Connect client record id, for `deleteByClientRecordId` (Android); null if none.
  final String? clientRecordId;

  /// When the write was made.
  final DateTime at;

  /// Whether the record can be looked up and deleted by its [uuid].
  bool get hasUuid => uuid != null;

  @override
  String toString() => 'RecentWrite(${type.name}, $description, uuid: $uuid)';
}

/// The writes of this session, newest first, at most [capacity] of them.
class RecentWrites extends ChangeNotifier {
  /// The most writes kept: older ones drop off the end.
  static const int capacity = 50;

  final List<RecentWrite> _items = [];

  /// The writes, newest first. Unmodifiable: use [add], [remove] and [clear].
  List<RecentWrite> get items => List.unmodifiable(_items);

  /// The writes that have a UUID, newest first: the ones `getHealthDataByUUID` can look up.
  List<RecentWrite> get withUuid => List.unmodifiable(_items.where((write) => write.hasUuid));

  /// The writes of [type], newest first, for example the workouts a route can be attached to.
  List<RecentWrite> ofType(HealthDataType type) => List.unmodifiable(_items.where((write) => write.type == type));

  /// Adds [write] as the newest entry, dropping the oldest beyond [capacity].
  void add(RecentWrite write) {
    _items.insert(0, write);
    if (_items.length > capacity) _items.removeRange(capacity, _items.length);
    notifyListeners();
  }

  /// Removes [write], for example after it was deleted.
  void remove(RecentWrite write) {
    if (_items.remove(write)) notifyListeners();
  }

  /// Forgets every write. The data itself stays in Health Connect or Apple Health.
  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
