part of '../../health.dart';

/// Part of [Health]: whether Health Connect is available on this phone, and
/// how to install it. Android only.
// ignore: library_private_types_in_public_api
mixin HealthConnectStatus on _HealthSupport {
  /// Checks the current status of Health Connect availability.
  ///
  /// See this for more info:
  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)
  ///
  /// Android only. Returns null on iOS or if an error occurs.
  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async {
    if (Platform.isIOS) return null;

    try {
      final status = await Health._channel.invokeMethod<int>('getHealthConnectSdkStatus');
      _healthConnectSdkStatus = status != null
          ? HealthConnectSdkStatus.fromNativeValue(status)
          : HealthConnectSdkStatus.sdkUnavailable;

      return _healthConnectSdkStatus;
    } catch (e) {
      debugPrint('$runtimeType - Exception in getHealthConnectSdkStatus(): $e');
      return null;
    }
  }

  /// Is Google Health Connect available on this phone?
  ///
  /// Android only. Returns always true on iOS.
  Future<bool> isHealthConnectAvailable() async =>
      !Platform.isAndroid ? true : (await getHealthConnectSdkStatus() == HealthConnectSdkStatus.sdkAvailable);

  /// Prompt the user to install the Google Health Connect app via the
  /// installed store (most likely Play Store).
  ///
  /// Android only. On iOS this does nothing.
  Future<void> installHealthConnect() async {
    if (Platform.isIOS) return;

    try {
      await Health._channel.invokeMethod('installHealthConnect');
    } catch (e) {
      debugPrint('$runtimeType - Exception in installHealthConnect(): $e');
    }
  }
}
