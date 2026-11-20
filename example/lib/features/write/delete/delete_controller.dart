/// The plugin calls of the Delete page: `Health.delete` (the app's data of some types in a time range)
/// and, on Android, `Health.deleteByClientRecordId` (one record by the app's own id for it).
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/time/time_range.dart';
import 'package:health_example/core/writes/recent_writes.dart';

/// What deleting one type's data did: idle until its turn, loading while the plugin deletes, then what
/// `delete` returned or threw.
typedef TypeDelete = ({HealthDataType type, AsyncValue<bool> result});

/// The Delete page's input and plugin calls. Nothing here throws at the UI: each call runs through
/// `AsyncValue.guard`.
///
/// Both platforms let an app delete only the data it wrote itself, so the types offered are the ones
/// the app can write ([TypeCatalog.deletableTypes]).
class DeleteController extends ChangeNotifier {
  /// Creates the controller, deleting through [health] the types [catalog] lists as deletable.
  DeleteController({
    required this.health,
    required this.capabilities,
    required this.catalog,
    required this.recentWrites,
  }) {
    // Start from the record this session last wrote with a client record id, such as the sample data's.
    final written = recentWrites.items.where((write) => write.clientRecordId != null && _isOffered(write.type));
    _clientIdType = written.firstOrNull?.type ?? deletableTypes.firstOrNull ?? HealthDataType.STEPS;
    clientRecordId.text = written.firstOrNull?.clientRecordId ?? '';
  }

  /// The plugin.
  final Health health;

  /// The platform: `deleteByClientRecordId` is Health Connect only.
  final PlatformCapabilities capabilities;

  /// The types this device supports, and which of them can be deleted.
  final TypeCatalog catalog;

  /// This session's writes, whose types and client record ids the page offers.
  final RecentWrites recentWrites;

  Set<HealthDataType> _types = {};
  TimeRange _range = TimeRange.preset(TimeRangePreset.last24Hours);
  List<TypeDelete> _results = const [];
  bool _deleting = false;
  late HealthDataType _clientIdType;
  AsyncValue<bool> _clientIdResult = const AsyncIdle();
  bool _disposed = false;

  /// The client record id to delete by (`clientRecordId`).
  final TextEditingController clientRecordId = TextEditingController();

  /// An optional Health Connect record id (UUID) deleted in the same call (`recordId`).
  final TextEditingController recordId = TextEditingController();

  /// The types `delete` can remove the app's data of.
  List<HealthDataType> get deletableTypes => catalog.deletableTypes;

  /// The types to delete in [range].
  Set<HealthDataType> get types => _types;
  set types(Set<HealthDataType> value) => _update(() => _types = value.where(_isOffered).toSet());

  /// The time range to delete in.
  TimeRange get range => _range;
  set range(TimeRange value) => _update(() => _range = value);

  /// The types of this session's writes that `delete` can remove, in catalogue order.
  List<HealthDataType> get writtenTypes {
    final written = {for (final write in recentWrites.items) write.type};
    return deletableTypes.where(written.contains).toList();
  }

  /// The types of the current or last [deleteInRange], each with what deleting it did.
  List<TypeDelete> get results => _results;

  /// Whether [deleteInRange] is running.
  bool get isDeleting => _deleting;

  /// The types of the current or last run that are done.
  int get finishedCount => _results.where((entry) => entry.result is AsyncData || entry.result is AsyncError).length;

  /// The type being deleted now, or null.
  HealthDataType? get currentType => _results.where((entry) => entry.result.isLoading).firstOrNull?.type;

  /// Deletes the app's data of each of [types] in [range] with `delete`, one type after the other, in
  /// catalogue order. A preset range ends now. A type whose call throws is marked and the next type is
  /// deleted all the same. Does nothing while a run is going on or without types.
  Future<void> deleteInRange() async {
    if (_deleting || _types.isEmpty) return;
    final range = _range = _range.refreshed();
    final ordered = deletableTypes.where(_types.contains).toList();
    _deleting = true;
    _update(() => _results = [for (final type in ordered) (type: type, result: const AsyncIdle<bool>())]);
    for (var i = 0; i < ordered.length; i++) {
      if (_disposed) return;
      _setResult(i, const AsyncLoading());
      final result = await AsyncValue.guard(
        () => health.delete(type: ordered[i], startTime: range.start, endTime: range.end),
      );
      _setResult(i, result);
    }
    _deleting = false;
    _update(() {});
  }

  /// Whether this platform deletes by client record id: only Health Connect has them.
  bool get supportsClientRecordId => capabilities.isAndroid;

  /// The data type of the record to delete by client record id (`dataTypeKey`).
  HealthDataType get clientIdType => _clientIdType;
  set clientIdType(HealthDataType value) => _update(() => _clientIdType = value);

  /// This session's writes that used a client record id, newest first.
  List<RecentWrite> get clientIdWrites => [
    for (final write in recentWrites.items)
      if (write.clientRecordId != null && _isOffered(write.type)) write,
  ];

  /// Fills the form with [write]'s type and client record id.
  void useWrite(RecentWrite write) => _update(() {
    _clientIdType = write.type;
    clientRecordId.text = write.clientRecordId ?? '';
    recordId.clear();
  });

  /// The state of the last [deleteByClientRecordId]: its data is what the plugin returned.
  AsyncValue<bool> get clientIdResult => _clientIdResult;

  /// Deletes the [clientIdType] record with the [clientRecordId] (and the record with [recordId], if
  /// given) with `deleteByClientRecordId`. On success, removes the matching writes from [recentWrites].
  /// Only on Android; an empty id is an `ArgumentError` result, without a plugin call. Never throws.
  Future<void> deleteByClientRecordId() async {
    if (!supportsClientRecordId || _clientIdResult.isLoading) return;
    final id = clientRecordId.text.trim();
    final type = _clientIdType;
    final uuid = recordId.text.trim();
    _update(() => _clientIdResult = const AsyncLoading());
    final result = await AsyncValue.guard(() async {
      if (id.isEmpty) throw ArgumentError.value(id, 'clientRecordId', 'Enter the client record id to delete');
      return health.deleteByClientRecordId(dataTypeKey: type, clientRecordId: id, recordId: uuid.isEmpty ? null : uuid);
    });
    if (_disposed) return;
    if (result case AsyncData(value: true)) {
      for (final write in recentWrites.items.where((write) => write.type == type && write.clientRecordId == id)) {
        recentWrites.remove(write);
      }
    }
    _update(() => _clientIdResult = result);
  }

  @override
  void dispose() {
    _disposed = true;
    clientRecordId.dispose();
    recordId.dispose();
    super.dispose();
  }

  bool _isOffered(HealthDataType type) => deletableTypes.contains(type);

  void _setResult(int index, AsyncValue<bool> result) =>
      _update(() => _results = [..._results]..[index] = (type: _results[index].type, result: result));

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }
}
