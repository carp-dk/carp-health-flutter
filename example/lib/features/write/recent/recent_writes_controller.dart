/// The plugin calls of the Write page's recent writes: deleting a record the app wrote, with
/// `Health.deleteByUUID` or, for a Health Connect record written without a UUID, with
/// `Health.deleteByClientRecordId`.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/writes/recent_writes.dart';

/// Deletes [recentWrites] entries' records and keeps the state of each delete.
///
/// A record deleted for good is also removed from [recentWrites]. A delete that returns false (the
/// platform refused, for example for another app's record) or throws keeps the entry, with the outcome
/// in [deleteStateOf]. Nothing here throws at the UI.
class RecentWritesController extends ChangeNotifier {
  /// Creates the controller for [recentWrites], deleting through [health] on the device [capabilities]
  /// describes.
  RecentWritesController({required this.health, required this.capabilities, required this.recentWrites});

  /// The plugin.
  final Health health;

  /// The platform: only Health Connect has client record ids.
  final PlatformCapabilities capabilities;

  /// The log of this session's writes.
  final RecentWrites recentWrites;

  // Keyed by identity: two writes of the same value are different entries.
  final Map<RecentWrite, AsyncValue<bool>> _deletes = {};
  bool _disposed = false;

  /// The state of the last delete of [write]: idle when there was none, loading while it runs, then
  /// what the plugin returned (false: nothing deleted) or threw.
  AsyncValue<bool> deleteStateOf(RecentWrite write) => _deletes[write] ?? const AsyncIdle();

  /// Whether [write]'s record can be deleted here: by its UUID, or on Android by its client record id.
  bool canDelete(RecentWrite write) => write.hasUuid || _clientRecordIdOf(write) != null;

  /// The plugin method that deletes [write]'s record.
  String deleteMethodOf(RecentWrite write) => write.hasUuid ? 'deleteByUUID' : 'deleteByClientRecordId';

  /// The entries still in the log whose last delete threw, newest first, for an `ErrorCard`.
  List<(RecentWrite, Object)> get failures => [
    for (final write in recentWrites.items)
      if (deleteStateOf(write) case AsyncError(:final error)) (write, error),
  ];

  /// Deletes [write]'s record: `deleteByUUID` with its UUID and type (iOS needs both), or on Android
  /// `deleteByClientRecordId` with its type and client record id. Does nothing while that delete runs
  /// or when the record cannot be deleted here. Never throws.
  Future<void> delete(RecentWrite write) async {
    if (deleteStateOf(write).isLoading || !canDelete(write)) return;
    _set(write, const AsyncLoading());
    final uuid = write.uuid;
    final result = await AsyncValue.guard(
      () => uuid != null
          ? health.deleteByUUID(uuid: uuid, type: write.type)
          : health.deleteByClientRecordId(dataTypeKey: write.type, clientRecordId: _clientRecordIdOf(write)!),
    );
    if (_disposed) return;
    if (result case AsyncData(value: true)) {
      _deletes.remove(write);
      // RecentWrites notifies its own listeners, which include the list.
      recentWrites.remove(write);
      _notify();
      return;
    }
    _set(write, result);
  }

  /// Forgets the outcome of [write]'s last delete, for example after its error was read.
  void dismiss(RecentWrite write) {
    if (_deletes.remove(write) != null) _notify();
  }

  /// Forgets every entry of the log. The records stay in Health Connect or Apple Health.
  void clear() {
    _deletes.clear();
    recentWrites.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// [write]'s client record id where the platform deletes by it: Health Connect only, as HealthKit
  /// has no client record ids.
  String? _clientRecordIdOf(RecentWrite write) => capabilities.isAndroid ? write.clientRecordId : null;

  void _set(RecentWrite write, AsyncValue<bool> state) {
    _deletes[write] = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
