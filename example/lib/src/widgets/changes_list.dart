part of '../../main.dart';

/// The changes pulled from Health Connect, below a summary of the last pull.
extension _ChangesList on HealthAppState {
  Widget get _contentChangesReady {
    final token = _changesToken;
    final tokenPreview = token == null ? 'none' : (token.length > 12 ? '${token.substring(0, 12)}...' : token);
    final previousToken = _previousChangesToken;
    final previousPreview = previousToken == null
        ? 'none'
        : (previousToken.length > 12 ? '${previousToken.substring(0, 12)}...' : previousToken);
    final lastChangesAt = _lastChangesAt;

    return ListView.builder(
      itemCount: _changes.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return ListTile(
            title: const Text('Health Connect Changes'),
            subtitle: Text(
              'prevToken: $previousPreview\n'
              'nextToken: $tokenPreview\n'
              'hasMore: $_changesHasMore | tokenExpired: $_changesTokenExpired\n'
              'applied upserts: $_lastAppliedUpserts | applied deletes: $_lastAppliedDeletes\n'
              'inserted: $_lastInserted | updated: $_lastUpdated | removed: $_lastRemoved\n'
              'store count: $_lastBeforeCount -> $_lastAfterCount\n'
              'last pull: ${lastChangesAt ?? "never"}',
            ),
          );
        }

        final change = _changes[index - 1];
        if (change.type == HealthChangeType.delete) {
          return ListTile(title: const Text('Delete'), subtitle: Text('recordId: ${change.recordId ?? "unknown"}'));
        }

        final dataPoint = change.dataPoint;
        if (dataPoint == null) {
          return ListTile(
            title: Text('Upsert ${change.dataType?.name ?? "UNKNOWN"}'),
            subtitle: const Text('No data point decoded.'),
          );
        }

        return ListTile(
          title: Text('${dataPoint.typeString}: ${dataPoint.value}'),
          trailing: Text(dataPoint.unitString),
          subtitle: Text('${dataPoint.dateFrom} - ${dataPoint.dateTo}'),
        );
      },
    );
  }
}
