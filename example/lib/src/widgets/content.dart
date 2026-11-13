part of '../../main.dart';

/// What the area below the buttons shows in each [AppState].
extension _Content on HealthAppState {
  Widget get _content => switch (_state) {
    AppState.DATA_READY => _contentDataReady,
    AppState.DATA_NOT_FETCHED => _contentNotFetched,
    AppState.FETCHING_DATA => _contentFetchingData,
    AppState.NO_DATA => _contentNoData,
    AppState.AUTHORIZED => _authorized,
    AppState.AUTH_NOT_GRANTED => _authorizationNotGranted,
    AppState.DATA_ADDED => _dataAdded,
    AppState.DATA_DELETED => _dataDeleted,
    AppState.DATA_NOT_ADDED => _dataNotAdded,
    AppState.DATA_NOT_DELETED => _dataNotDeleted,
    AppState.STEPS_READY => _stepsFetched,
    AppState.HEALTH_CONNECT_STATUS => _contentHealthConnectStatus,
    AppState.SKIN_TEMPERATURE_FEATURE_STATUS => _contentSkinTemperatureFeatureStatus,
    AppState.PERMISSIONS_REVOKING => _permissionsRevoking,
    AppState.PERMISSIONS_REVOKED => _permissionsRevoked,
    AppState.PERMISSIONS_NOT_REVOKED => _permissionsNotRevoked,
    AppState.CHANGES_READY => _contentChangesReady,
    AppState.CHANGES_NOT_READY => _contentChangesNotReady,
  };

  Widget get _contentNotFetched => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text("Press 'Authenticate' to get permissions to access health data."),
      Text("Press 'Fetch Data' to get health data."),
      Text("Press 'Add Data' to add some random health data."),
      Text("Press 'Delete Data' to remove some random health data."),
    ],
  );

  Widget get _contentFetchingData => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      Container(padding: const EdgeInsets.all(20), child: const CircularProgressIndicator(strokeWidth: 10)),
      const Text('Fetching data...'),
    ],
  );

  Widget get _contentNoData => const Text('No Data to show');

  Widget get _authorized => const Text('Authorization granted!');

  Widget get _authorizationNotGranted => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('Authorization not given.'),
      Text(
        'For Google Health Connect please check if you have added the right permissions and services to the manifest file.',
      ),
      Text('For Apple Health check your permissions in Apple Health.'),
    ],
  );

  Widget get _dataAdded => const Text('Data points inserted successfully.');

  Widget get _dataDeleted => const Text('Data points deleted successfully.');

  Widget get _dataNotAdded => const Text('Failed to add data.\nDo you have permissions to add data?');

  Widget get _dataNotDeleted => const Text('Failed to delete data');

  Widget get _stepsFetched => Text('Total number of steps: $_nofSteps.');

  Widget get _permissionsRevoking => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      Container(padding: const EdgeInsets.all(20), child: const CircularProgressIndicator(strokeWidth: 10)),
      const Text('Revoking permissions...'),
    ],
  );

  Widget get _permissionsRevoked => const Text('Permissions revoked.');

  Widget get _permissionsNotRevoked => const Text('Failed to revoke permissions');

  Widget get _contentChangesNotReady =>
      const Text('No change token yet. Tap "Create Changes Token" after authorization.');
}
