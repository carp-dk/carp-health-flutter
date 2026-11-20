/// The state and plugin calls of Read > Changes (Android only): following what was added, changed and
/// deleted in Health Connect with `Health.getChangesToken` and `Health.getChanges`, and applying it to a
/// local copy of the records ([SyncedRecords]).
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';

import '../type_order.dart';
import 'changes_summary.dart';
import 'synced_records.dart';

/// Holds the types to follow, the changes token and the local copy; makes the two plugin calls. The
/// Changes section listens. On iOS, which has no changes API, every call is skipped ([isSupported]).
class ChangesController extends ChangeNotifier {
  /// Creates the controller, calling the plugin through [health] on the platform [capabilities] describes,
  /// and following steps and workouts (those of them in [available]) to start with, as the old example did.
  ChangesController({required this.health, required this.capabilities, required List<HealthDataType> available})
    : _types = initialTypes(const {HealthDataType.STEPS, HealthDataType.WORKOUT}, available);

  /// The most `getChanges` calls one sync makes. Each call costs Health Connect quota, so a large backlog
  /// is fetched over several syncs; the token keeps the place.
  static const int maxCallsPerSync = 20;

  /// The most entries [recent] keeps.
  static const int recentCapacity = 100;

  /// The plugin instance the calls go through.
  final Health health;

  /// The platform, which decides whether the changes API exists.
  final PlatformCapabilities capabilities;

  /// The local copy the changes are applied to.
  final SyncedRecords records = SyncedRecords();

  Set<HealthDataType> _types;
  bool _includeSelf = true;
  AsyncValue<String> _tokenRequest = const AsyncIdle();
  String? _token;
  String? _previousToken;
  List<HealthDataType> _tokenTypes = const [];
  DateTime? _tokenCreatedAt;
  bool _tokenExpired = false;
  AsyncValue<ChangesSummary> _sync = const AsyncIdle();
  DateTime? _lastSyncAt;
  final List<ChangeEntry> _recent = [];
  bool _disposed = false;

  /// Whether the platform has the changes API: Health Connect does, and on iOS both calls return null.
  bool get isSupported => capabilities.isAndroid;

  /// The types a new token follows (`types` of `getChangesToken`).
  Set<HealthDataType> get types => _types;

  set types(Set<HealthDataType> types) {
    _types = Set.unmodifiable(types);
    _notify();
  }

  /// Whether syncs include the records this app wrote (`includeSelf` of `getChanges`). The plugin leaves
  /// them out by default, as an app knows its own writes; this example includes them, so that what it
  /// writes shows up here. Deletions always come, as Health Connect does not say who deleted a record.
  bool get includeSelf => _includeSelf;

  set includeSelf(bool include) {
    _includeSelf = include;
    _notify();
  }

  /// The state of the last `getChangesToken` call.
  AsyncValue<String> get tokenRequest => _tokenRequest;

  /// The token the next sync starts from: the one `getChangesToken` made, then each sync's
  /// `nextChangesToken`; null before a token was made.
  String? get token => _token;

  /// The token the last page of changes was read with.
  String? get previousToken => _previousToken;

  /// The types [token] follows.
  List<HealthDataType> get tokenTypes => _tokenTypes;

  /// When [token]'s chain started.
  DateTime? get tokenCreatedAt => _tokenCreatedAt;

  /// Whether Health Connect reported the token as expired (`changesTokenExpired`): it can no longer be
  /// used, and the data must be read again before a new token is made.
  bool get tokenExpired => _tokenExpired;

  /// Whether [token] follows exactly the selected [types].
  bool get tokenFollowsSelection => setEquals(_tokenTypes.toSet(), _types);

  /// The state of the last sync: its summary while it runs (as the loading state's previous value) and
  /// when it ended, or the error of a sync whose first call failed.
  AsyncValue<ChangesSummary> get sync => _sync;

  /// When the last sync ended.
  DateTime? get lastSyncAt => _lastSyncAt;

  /// What the syncs since the token was made did, record by record, newest first.
  List<ChangeEntry> get recent => List.unmodifiable(_recent);

  /// Whether a call runs.
  bool get isBusy => _tokenRequest.isLoading || _sync.isLoading;

  /// Whether a token can be made: on Android, with types chosen, while no call runs.
  bool get canCreateToken => isSupported && !isBusy && _types.isNotEmpty;

  /// Whether changes can be fetched: there is a token that has not expired and no call runs.
  bool get canSync => isSupported && !isBusy && _token != null && !_tokenExpired;

  /// Whether [clearLocalCopy] has something to clear (records, recent changes or a sync) while no call runs.
  bool get canClearLocalCopy => !isBusy && (records.recordCount > 0 || _recent.isNotEmpty || _sync is! AsyncIdle);

  /// Makes a changes token for [types] with `getChangesToken`, which later syncs start from. The local
  /// copy stays; the list of recent changes starts over. Never throws.
  Future<void> createToken() async {
    if (!canCreateToken) return;
    final types = inDisplayOrder(_types);
    _tokenRequest = _tokenRequest.toLoading();
    _notify();
    final result = await AsyncValue.guard(() async {
      final token = await health.getChangesToken(types: types);
      // Null only on iOS, where this section makes no calls.
      if (token == null || token.isEmpty) throw StateError('getChangesToken returned no token.');
      return token;
    });
    if (_disposed) return;
    if (result case AsyncData(value: final token)) {
      _token = token;
      _previousToken = null;
      _tokenTypes = List.unmodifiable(types);
      _tokenCreatedAt = DateTime.now();
      _tokenExpired = false;
      _sync = const AsyncIdle();
      _recent.clear();
    }
    _tokenRequest = result;
    _notify();
  }

  /// Fetches the changes since [token] with `getChanges`, again while `hasMore` (at most [maxCallsPerSync]
  /// calls), and applies them to [records]. Never throws.
  ///
  /// The token moves on with every page, so a failed call (such as `rateLimitExceeded`) loses nothing:
  /// the pages before it stay applied, and the next sync starts after them. An expired token ends the
  /// sync; see [tokenExpired].
  Future<void> fetchChanges() async {
    final start = _token;
    if (!canSync || start == null) return;
    final includeSelf = _includeSelf;
    final stopwatch = Stopwatch()..start();
    var summary = ChangesSummary.start(records.recordCount);
    _sync = AsyncLoading(previous: summary);
    _notify();
    var token = start;
    try {
      do {
        final response = await health.getChanges(changesToken: token, includeSelf: includeSelf);
        if (_disposed) return;
        // Null only on iOS, where this section makes no calls.
        if (response == null) throw StateError('getChanges returned null.');
        final applied = records.apply(response.changes);
        _addRecent(applied.entries);
        _tokenExpired = response.changesTokenExpired;
        // An expired token's successor is of no use: a new token must be made.
        if (!_tokenExpired && response.nextChangesToken.isNotEmpty) {
          _previousToken = token;
          token = _token = response.nextChangesToken;
        }
        summary = summary.add(
          applied,
          records: records.recordCount,
          hasMore: response.hasMore,
          tokenExpired: response.changesTokenExpired,
          elapsed: stopwatch.elapsed,
        );
        _sync = AsyncLoading(previous: summary);
        _notify();
      } while (summary.hasMore && !summary.tokenExpired && summary.calls < maxCallsPerSync);
      _sync = AsyncData(summary.finish(stopwatch.elapsed));
    } catch (error, stackTrace) {
      if (_disposed) return;
      _sync = summary.calls == 0
          ? AsyncError(error, stackTrace)
          : AsyncData(summary.finish(stopwatch.elapsed, error: error, stackTrace: stackTrace));
    }
    _lastSyncAt = DateTime.now();
    _notify();
  }

  /// Forgets the local copy and the recent changes, as before reading everything again. The token stays.
  void clearLocalCopy() {
    if (isBusy) return;
    records.clear();
    _recent.clear();
    _sync = const AsyncIdle();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Puts [entries] at the top of [recent], newest first, keeping at most [recentCapacity].
  void _addRecent(List<ChangeEntry> entries) {
    _recent.insertAll(0, entries.reversed);
    if (_recent.length > recentCapacity) _recent.removeRange(recentCapacity, _recent.length);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
