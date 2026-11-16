/// The state and plugin calls of an open data point sheet: reading the record again by its UUID and
/// deleting it.
///
/// Demonstrates `Health.getHealthDataByUUID` and `Health.deleteByUUID`.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/writes/recent_writes.dart';

/// Holds the data point a sheet shows and runs the sheet's two plugin calls on it; the sheet listens
/// and rebuilds.
class DataPointSheetController extends ChangeNotifier {
  /// Creates the controller for the data point [_point], calling the plugin through [health]. A
  /// successful delete also removes the point from [recentWrites], so the Write page's list stays true.
  DataPointSheetController(this._point, {required this.health, this.recentWrites});

  /// The plugin instance the calls go through.
  final Health health;

  /// The app's log of its writes, or null where the app does not provide one.
  final RecentWrites? recentWrites;

  HealthDataPoint _point;
  AsyncValue<HealthDataPoint?> _lookup = const AsyncIdle();
  AsyncValue<bool> _deletion = const AsyncIdle();
  DateTime? _lookedUpAt;
  bool _disposed = false;

  /// The data point shown: the one the sheet opened with, or the record [rereadByUuid] found.
  HealthDataPoint get point => _point;

  /// The state of the last [rereadByUuid]: its data is the record found, or null when there was none.
  AsyncValue<HealthDataPoint?> get lookup => _lookup;

  /// The state of [deleteByUuid]: its data is what `deleteByUUID` returned.
  AsyncValue<bool> get deletion => _deletion;

  /// When [rereadByUuid] last completed.
  DateTime? get lookedUpAt => _lookedUpAt;

  /// Whether the point has a UUID to read or delete it by. Interval data points
  /// (`getHealthIntervalDataFromTypes`) are aggregates, not records, and have none.
  bool get hasUuid => _point.uuid.isNotEmpty;

  /// Whether a call is running; the sheet disables its actions meanwhile.
  bool get isBusy => _lookup.isLoading || _deletion.isLoading;

  /// Whether the record was deleted.
  bool get isDeleted => _deletion.valueOrNull ?? false;

  /// Reads the record again with `getHealthDataByUUID` and shows what it returns.
  ///
  /// The plugin returns null when no record has the UUID (any more), on Android also when the record
  /// has no data of the type asked for, and for another app's record without the read permission.
  Future<void> rereadByUuid() async {
    if (!hasUuid || isBusy || isDeleted) return;
    _update(() => _lookup = _lookup.toLoading());
    final result = await AsyncValue.guard(() => health.getHealthDataByUUID(uuid: _point.uuid, type: _point.type));
    _update(() {
      if (result case AsyncData(value: final found?)) _point = found;
      _lookup = result;
      _lookedUpAt = DateTime.now();
    });
  }

  /// Deletes the record with `deleteByUUID` and returns whether it was deleted.
  ///
  /// The type goes with the UUID, as iOS requires it. Apps can delete only the records they wrote
  /// themselves: for another app's record, or one that no longer exists, the plugin returns false.
  Future<bool> deleteByUuid() async {
    if (!hasUuid || isBusy || isDeleted) return false;
    _update(() => _deletion = const AsyncLoading());
    final result = await AsyncValue.guard(() => health.deleteByUUID(uuid: _point.uuid, type: _point.type));
    final deleted = result.valueOrNull ?? false;
    if (deleted) {
      final log = recentWrites;
      for (final write in log?.items.where((write) => write.uuid == _point.uuid) ?? const <RecentWrite>[]) {
        log!.remove(write);
      }
    }
    _update(() => _deletion = result);
    return deleted;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Applies [change] and notifies, unless the sheet closed while a call ran.
  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }
}
