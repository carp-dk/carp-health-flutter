part of '../../main.dart';

class _ChangesSummary {
  final int beforeCount;
  final int afterCount;
  final int inserted;
  final int updated;
  final int removed;
  final int appliedUpserts;
  final int appliedDeletes;

  const _ChangesSummary({
    required this.beforeCount,
    required this.afterCount,
    required this.inserted,
    required this.updated,
    required this.removed,
    required this.appliedUpserts,
    required this.appliedDeletes,
  });
}

/// Incremental sync through the Health Connect changes API (Android only).
extension _ChangesActions on HealthAppState {
  /// Create a change token for Health Connect incremental sync.
  Future<void> createChangesToken() async {
    if (!Platform.isAndroid) {
      setState(() => _state = AppState.CHANGES_NOT_READY);
      return;
    }

    try {
      // null only on iOS
      final token = await health.getChangesToken(types: _changeTypes);
      setState(() {
        _changesToken = token;
        _changesTokenExpired = false;
        _changesHasMore = false;
        _changes.clear();
        _state = token == null ? AppState.CHANGES_NOT_READY : AppState.CHANGES_READY;
      });
    } on HealthPlatformException catch (error) {
      // Health Connect reported an error, for example
      // HealthErrorCode.rateLimitExceeded, which is worth retrying later.
      debugPrint(
        "Exception in createChangesToken: $error - "
        "errorCode: ${error.errorCode}, retryable: ${error.isRetryable}",
      );
      setState(() => _state = AppState.CHANGES_NOT_READY);
    } catch (error) {
      debugPrint("Exception in createChangesToken: $error");
      setState(() => _state = AppState.CHANGES_NOT_READY);
    }
  }

  /// Fetch the next page of changes using the current token.
  Future<void> fetchChanges() async {
    if (!Platform.isAndroid) {
      setState(() => _state = AppState.CHANGES_NOT_READY);
      return;
    }

    final token = _changesToken;
    if (token == null || token.isEmpty) {
      setState(() => _state = AppState.CHANGES_NOT_READY);
      return;
    }

    try {
      final response = await health.getChanges(changesToken: token);
      // null only on iOS
      if (response == null) {
        setState(() => _state = AppState.CHANGES_NOT_READY);
        return;
      }

      final summary = _applyChanges(response.changes);

      setState(() {
        _previousChangesToken = token;
        _changesToken = response.nextChangesToken;
        _changesTokenExpired = response.changesTokenExpired;
        _changesHasMore = response.hasMore;
        _changes.addAll(response.changes);
        _lastBeforeCount = summary.beforeCount;
        _lastAfterCount = summary.afterCount;
        _lastInserted = summary.inserted;
        _lastUpdated = summary.updated;
        _lastRemoved = summary.removed;
        _lastAppliedUpserts = summary.appliedUpserts;
        _lastAppliedDeletes = summary.appliedDeletes;
        _lastChangesAt = DateTime.now();
        _state = AppState.CHANGES_READY;
      });
    } on HealthPlatformException catch (error) {
      // Health Connect reported an error, for example
      // HealthErrorCode.rateLimitExceeded: the token stays valid, so fetch
      // again later.
      debugPrint(
        "Exception in fetchChanges: $error - "
        "errorCode: ${error.errorCode}, retryable: ${error.isRetryable}",
      );
      setState(() => _state = AppState.CHANGES_NOT_READY);
    } catch (error) {
      debugPrint("Exception in fetchChanges: $error");
      setState(() => _state = AppState.CHANGES_NOT_READY);
    }
  }

  _ChangesSummary _applyChanges(List<HealthChange> changes) {
    final beforeCount = _syncedDataById.length;
    int inserted = 0;
    int updated = 0;
    int removed = 0;
    int appliedUpserts = 0;
    int appliedDeletes = 0;

    for (final change in changes) {
      if (change.type == HealthChangeType.delete) {
        appliedDeletes += 1;
        final recordId = change.recordId;
        if (recordId != null && _syncedDataById.remove(recordId) != null) {
          removed += 1;
        }
        continue;
      }

      appliedUpserts += 1;
      final dataPoint = change.dataPoint;
      if (dataPoint == null || dataPoint.uuid.isEmpty) {
        continue;
      }

      final existing = _syncedDataById[dataPoint.uuid];
      _syncedDataById[dataPoint.uuid] = dataPoint;
      if (existing == null) {
        inserted += 1;
      } else if (existing != dataPoint) {
        updated += 1;
      }
    }

    return _ChangesSummary(
      beforeCount: beforeCount,
      afterCount: _syncedDataById.length,
      inserted: inserted,
      updated: updated,
      removed: removed,
      appliedUpserts: appliedUpserts,
      appliedDeletes: appliedDeletes,
    );
  }
}
