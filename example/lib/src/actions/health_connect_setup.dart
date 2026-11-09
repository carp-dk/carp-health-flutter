part of '../../main.dart';

/// Health Connect setup on Android: checking the SDK status and installing Health Connect.
extension _HealthConnectSetupActions on HealthAppState {
  /// Install Google Health Connect on this phone.
  Future<void> installHealthConnect() async => await health.installHealthConnect();

  /// Gets the Health Connect status on Android.
  Future<void> getHealthConnectSdkStatus() async {
    assert(Platform.isAndroid, "This is only available on Android");

    final status = await health.getHealthConnectSdkStatus();

    setState(() {
      _contentHealthConnectStatus = Text('Health Connect Status: ${status?.name.toUpperCase()}');
      _state = AppState.HEALTH_CONNECT_STATUS;
    });
  }
}
